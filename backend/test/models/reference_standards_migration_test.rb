require "test_helper"
require Rails.root.join("db/migrate/20260920140100_seed_reference_standards")

# 基準器のデモ用データの、既存環境への反映マイグレーション
class ReferenceStandardsMigrationTest < ActiveSupport::TestCase
  setup do
    @kawasaki = Site.create!(name: "川崎製油所")
    @today = InspectionPlan.today
  end

  def run_migration
    ActiveRecord::Migration.suppress_messages { SeedReferenceStandards.new.up }
  end

  test "拠点が一致する基準器と、校正の履歴、年次校正の点検計画（次回期限は最新の校正の有効期限）を作り、何度実行しても増えない" do
    2.times { run_migration }

    kawasaki_count = ReferenceStandardCatalog::STANDARDS.count { |attrs| attrs[:site] == "川崎製油所" }
    assert_equal kawasaki_count, ReferenceStandard.count
    standard = ReferenceStandard.find_by!(management_number: "RS-KW-001")
    assert_equal [ @kawasaki, "usable", "valid" ], [ standard.site, standard.status, standard.calibration_state ]
    assert_equal 1, standard.inspection_plans.count
    plan = standard.inspection_plans.first
    assert_equal [ standard.next_due_on, standard.latest_calibration.performed_on ], [ plan.next_due_on, plan.last_inspected_on ]
    assert_nil plan.equipment_id
  end

  test "期限切れ・期限間近・不合格・校正中の各状態が、履歴どおりに再現される" do
    run_migration

    states = ReferenceStandard.all.to_h { |standard| [ standard.management_number, [ standard.status, standard.calibration_state ] ] }
    assert_equal %w[usable expired], states["RS-KW-003"]
    assert_equal %w[usable expiring], states["RS-KW-002"]
    assert_equal %w[usable failed], states["RS-KW-007"]
    assert_equal %w[in_calibration expired], states["RS-KW-006"]
    assert_equal 2, ReferenceStandard.find_by!(management_number: "RS-KW-007").calibrations.count
  end

  test "管理番号が一致する基準器には触れず、拠点が無い環境には作らない" do
    existing = ReferenceStandard.create!(site: @kawasaki, management_number: "RS-KW-001", name: "編集済みの名前", category: "pressure")

    run_migration

    assert_equal "編集済みの名前", existing.reload.name
    assert_empty existing.calibrations
    assert_nil ReferenceStandard.find_by(management_number: "RS-NG-001") # 根岸製油所が無い
  end
end
