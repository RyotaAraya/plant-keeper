require "test_helper"
require Rails.root.join("db/migrate/20260927000000_create_inspection_plan_groups")

# 既存の点検計画を、拠点 × チェックリストのまとまりに入れるマイグレーション。
# テストの中でまとまりのテーブルを消してから流し直す（PostgreSQL の DDL はトランザクションの中で戻る）
class InspectionPlanGroupsMigrationTest < ActiveSupport::TestCase
  setup do
    @site = Site.create!(name: "川崎製油所")
    @other_site = Site.create!(name: "根岸製油所")
    @section = create_department(site: @site, name: "計装保全課")
    @template = ChecklistTemplate.create!(name: "伝送器 月次点検", department: @section, inspection_type: "periodic")
    @equipment = create_equipment(site: @site)
    @other_equipment = create_equipment(site: @other_site)
    @regulation = Regulation.create!(code: "boiler_pressure_vessel", name: "ボイラー", law_name: "労働安全衛生法")
    @safety_valve = ChecklistTemplate.create!(name: "安全弁 年次点検", department: @section, inspection_type: "periodic")
    ActiveRecord::Migration.suppress_messages { CreateInspectionPlanGroups.new.down }
    InspectionPlan.reset_column_information
  end

  teardown { InspectionPlan.reset_column_information }

  def insert_plan(name, equipment_id: @equipment.id, template: @template, interval: 30, reference_standard_id: nil)
    ActiveRecord::Base.connection.select_value(<<~SQL.squish)
      INSERT INTO inspection_plans (name, equipment_id, reference_standard_id, checklist_template_id, inspection_type, interval_days, next_due_on, is_active, created_at, updated_at)
      VALUES (#{[ name, equipment_id, reference_standard_id, template&.id, "periodic", interval, InspectionPlan.today ].map { |v| ActiveRecord::Base.connection.quote(v) }.join(', ')}, TRUE, NOW(), NOW())
      RETURNING id
    SQL
  end

  test "拠点 × チェックリストでまとめ、担当部署・既定の周期・デモの法規区分を入れ、すべての計画がまとまりに属する" do
    standard_id = ActiveRecord::Base.connection.select_value(<<~SQL.squish)
      INSERT INTO reference_standards (site_id, management_number, name, category, status, created_at, updated_at)
      VALUES (#{@site.id}, 'RS-1', '圧力校正器', 'pressure', 'usable', NOW(), NOW()) RETURNING id
    SQL
    ids = [ insert_plan("FT-101"), insert_plan("FT-102", interval: 60), insert_plan("FT-103"), insert_plan("根岸 FT-201", equipment_id: @other_equipment.id),
            insert_plan("外観点検", template: nil), insert_plan("圧力校正器 年次校正", equipment_id: nil, template: nil, interval: 365, reference_standard_id: standard_id),
            insert_plan("安全弁", template: @safety_valve, interval: 365) ]

    ActiveRecord::Migration.suppress_messages { CreateInspectionPlanGroups.new.up }
    InspectionPlan.reset_column_information

    plans = InspectionPlan.where(id: ids).includes(inspection_plan_group: :department).index_by(&:name)
    group = plans["FT-101"].inspection_plan_group
    assert_equal [ @site, "伝送器 月次点検", @section, 30 ], [ group.site, group.name, group.department, group.default_interval_days ]
    assert_equal [ group, group ], [ plans["FT-102"].inspection_plan_group, plans["FT-103"].inspection_plan_group ]
    # 別の拠点の計画は、同じチェックリストでも別のまとまり。部署はまとまりと同じ拠点のときだけ
    other = plans["根岸 FT-201"].inspection_plan_group
    assert_equal [ @other_site, "伝送器 月次点検", nil ], [ other.site, other.name, other.department ]
    assert_equal "チェックリストなしの点検", plans["外観点検"].inspection_plan_group.name
    assert_equal "川崎製油所 基準器の年次校正", plans["圧力校正器 年次校正"].inspection_plan_group.name
    assert_equal @regulation, plans["安全弁"].inspection_plan_group.regulation
    assert_not InspectionPlan.columns_hash["inspection_plan_group_id"].null
  end
end
