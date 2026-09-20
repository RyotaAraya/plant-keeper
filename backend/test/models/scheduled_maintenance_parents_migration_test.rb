require "test_helper"
require Rails.root.join("db/migrate/20260921000100_backfill_scheduled_maintenance_parents")

# 既存の定期整備（設備1件・予定日・完了日）を、単体の親に移行するマイグレーション
class ScheduledMaintenanceParentsMigrationTest < ActiveSupport::TestCase
  setup do
    @site = create_site
    @equipment = create_equipment(site: @site)
    @connection = ActiveRecord::Base.connection
    # 移行前の状態（拠点と予定開始日が未設定）を作るため、必須を一時的に外す（テストのトランザクションで元に戻る）
    @connection.change_column_null :scheduled_maintenances, :site_id, true
    @connection.change_column_null :scheduled_maintenances, :planned_start_on, true
  end

  def insert_legacy(title:, scheduled_date:, completed_date: nil, status: "planned")
    @connection.execute(<<~SQL.squish)
      INSERT INTO scheduled_maintenances (equipment_id, title, scheduled_date, completed_date, status, created_at, updated_at)
      VALUES (#{@equipment.id}, #{@connection.quote(title)}, #{@connection.quote(scheduled_date)}, #{@connection.quote(completed_date)}, #{@connection.quote(status)}, NOW(), NOW())
    SQL
    ScheduledMaintenance.find_by!(title: title)
  end

  def run_migration
    ActiveRecord::Migration.suppress_messages { BackfillScheduledMaintenanceParents.new.up }
  end

  test "拠点は設備から、対象設備は元の設備1件、予定開始日は予定日、実績の終了日は完了日、状態はそのまま" do
    planned = insert_legacy(title: "計画", scheduled_date: Date.new(2026, 4, 1))
    completed = insert_legacy(title: "完了", scheduled_date: Date.new(2025, 11, 1), completed_date: Date.new(2025, 11, 3), status: "completed")
    assignment = MaintenanceAssignment.create!(scheduled_maintenance: planned, user: create_user, role: "lead")

    2.times { run_migration }

    planned.reload
    assert_equal [ @site, Date.new(2026, 4, 1), "planned", [ @equipment ] ], [ planned.site, planned.planned_start_on, planned.status, planned.equipments.to_a ]
    completed.reload
    assert_equal [ Date.new(2025, 11, 1), Date.new(2025, 11, 3), "completed", 1 ], [ completed.planned_start_on, completed.actual_end_on, completed.status, completed.equipments.count ]
    assert_nil completed.accepted_on # 検収の記録はない（移行した完了済みのデータ）
    assert_equal planned, assignment.reload.scheduled_maintenance # 担当者は引き継がれる
    assert_equal 2, ScheduledMaintenanceEquipment.count
  end

  test "移行後は、拠点と予定開始日が必須になる" do
    insert_legacy(title: "計画", scheduled_date: Date.new(2026, 4, 1))

    run_migration

    # モデルの列情報のキャッシュを介さず、DBから直接読む（実行順で、キャッシュが移行前の状態のまま残ることがあるため）
    columns = @connection.columns(:scheduled_maintenances).index_by(&:name)
    assert_not columns["site_id"].null
    assert_not columns["planned_start_on"].null
  end
end
