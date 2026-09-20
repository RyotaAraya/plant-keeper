require "test_helper"
require Rails.root.join("db/migrate/20260921090000_group_demo_patrol_plans")

# デモの巡回の点検計画を、いくつかの装置をまとめた計画にする、既存環境への反映マイグレーション
class GroupDemoPatrolPlansMigrationTest < ActiveSupport::TestCase
  setup do
    @site = Site.create!(name: "川崎製油所")
    @section = create_department(site: @site, name: "製造部")
    @equipments = %w[常圧蒸留装置 重油間接脱硫装置 流動接触分解装置 減圧蒸留装置 接触改質装置 ボイラー設備].to_h { |name| [ name, create_equipment(site: @site, name: name) ] }
    @patrol = ChecklistTemplate.create!(name: "巡回点検", department: @section, inspection_type: "routine", cycle: "patrol")
  end

  def plan(name, template: @patrol, equipment: @equipments["常圧蒸留装置"])
    InspectionPlan.create!(name: name, equipment: equipment, checklist_template: template, inspection_type: "routine",
                           interval_days: 7, last_inspected_on: InspectionPlan.today - 9, next_due_on: InspectionPlan.today - 2)
  end

  def run_migration
    ActiveRecord::Migration.suppress_messages { GroupDemoPatrolPlans.new.up }
  end

  test "巡回の計画に、ほかの装置を足し、名前を直す（代表の設備は変えない）。何度実行しても同じ" do
    plan = plan("常圧蒸留装置 巡回点検")

    2.times { run_migration }

    plan.reload
    assert_equal "製造部 巡回点検", plan.name
    assert_equal @equipments["常圧蒸留装置"], plan.equipment
    assert_equal %w[常圧蒸留装置 重油間接脱硫装置 流動接触分解装置 減圧蒸留装置 接触改質装置].sort, plan.equipments.pluck(:name).sort
  end

  test "旧名（計器日常点検）の計画も対象にする" do
    plan = plan("常圧蒸留装置 計器日常点検")

    run_migration

    assert_equal "製造部 巡回点検", plan.reload.name
  end

  test "巡回でないテンプレートの計画、別の名前の計画、別の設備の計画には触れない" do
    monthly = ChecklistTemplate.create!(name: "月次", department: @section, inspection_type: "periodic", cycle: "monthly")
    other_template = plan("常圧蒸留装置 巡回点検", template: monthly)
    other_name = plan("独自の巡回")
    other_equipment = plan("常圧蒸留装置 巡回点検", equipment: @equipments["ボイラー設備"])

    run_migration

    [ other_template, other_name, other_equipment ].each { |p| assert_equal 1, p.reload.equipments.count }
    assert_equal [ "常圧蒸留装置 巡回点検", "独自の巡回", "常圧蒸留装置 巡回点検" ], [ other_template, other_name, other_equipment ].map(&:name)
  end

  test "対象の計画がない環境（拠点・設備がない）でも、エラーにならない" do
    assert_nothing_raised { run_migration }
  end
end
