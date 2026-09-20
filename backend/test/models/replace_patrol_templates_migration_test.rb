require "test_helper"
require Rails.root.join("db/migrate/20260921060000_replace_patrol_templates")

# 巡回点検を、機器の種類ごとから、装置単位の「巡回点検」に置き換える、既存環境への反映マイグレーション
class ReplacePatrolTemplatesMigrationTest < ActiveSupport::TestCase
  setup do
    @site = Site.create!(name: "川崎製油所")
    division = create_department(site: @site, name: "保全部")
    @section = create_department(site: @site, name: "計装保全課", level: "section", parent: division)
    @equipment = create_equipment(site: @site)
    @today = InspectionPlan.today
  end

  def old_template(name, active: true)
    ChecklistTemplate.create!(name: name, department: @section, inspection_type: "routine", cycle: "patrol", is_active: active)
  end

  def plan(name, template)
    InspectionPlan.create!(name: name, equipment: @equipment, checklist_template: template, inspection_type: "routine",
                           interval_days: 7, last_inspected_on: @today - 3, next_due_on: @today + 4)
  end

  def run_migration
    ActiveRecord::Migration.suppress_messages { ReplacePatrolTemplates.new.up }
  end

  test "新しい巡回点検を、項目つきで作り、何度実行しても増えない（部署が無い拠点には作らない）" do
    2.times { run_migration }

    patrol = ChecklistTemplate.where(name: "巡回点検")
    assert_equal 1, patrol.count
    template = patrol.first
    assert_equal [ @section, "routine", "patrol", true ], [ template.department, template.inspection_type, template.cycle, template.is_active ]
    assert_equal ChecklistTemplateCatalog::PATROL, template.checklist_template_items.map { |i| [ i.content, i.item_type ] }
    assert_equal (1..template.checklist_template_items.size).to_a, template.checklist_template_items.map(&:position)
    assert_nil ChecklistTemplate.find_by(name: "根岸 巡回点検") # 根岸には計装保全課が無い
  end

  test "機器の種類ごとの旧の巡回点検は、消さずに廃止にし、過去の点検記録の参照は残る。利用者が作ったテンプレートには触れない" do
    old = old_template("伝送器 巡回点検")
    inspection = Inspection.create!(user: create_user, equipment: @equipment, department: @section, checklist_template: old,
                                    inspection_type: "routine", status: "approved", inspected_at: Time.current)
    custom = old_template("独自の巡回")

    run_migration

    assert_not old.reload.is_active
    assert_equal old, inspection.reload.checklist_template
    assert custom.reload.is_active
  end

  test "旧の巡回点検（4種類）を使っていた点検計画を、新しい巡回点検に付け替え、デモの計画は名前も直す" do
    plans = [ "伝送器 巡回点検", "調節弁 巡回点検", "遮断弁・インターロック 巡回点検", "安全弁 巡回点検" ].map do |name|
      plan(name == "伝送器 巡回点検" ? "常圧蒸留装置 計器日常点検" : "#{name}の計画", old_template(name))
    end
    custom = plan("独自", old_template("独自の巡回"))

    run_migration

    assert_equal [ "巡回点検" ] * 4, plans.map { |p| p.reload.checklist_template.name }
    assert_equal "常圧蒸留装置 巡回点検", plans.first.name
    assert_equal [ "調節弁 巡回点検の計画" ], [ plans.second.name ] # デモの計画以外は名前を変えない
    assert_equal "独自の巡回", custom.reload.checklist_template.name
  end

  test "付け替え先を作れない拠点の計画は、消さず、名前も変えない" do
    negishi_site = Site.create!(name: "根岸製油所")
    department = create_department(site: negishi_site, name: "保全部")
    old = ChecklistTemplate.create!(name: "根岸 伝送器 巡回点検", department: department, inspection_type: "routine", cycle: "patrol")
    negishi = plan("常圧蒸留装置 計器日常点検", old)

    run_migration

    assert_equal [ "根岸 伝送器 巡回点検", "常圧蒸留装置 計器日常点検" ], [ negishi.reload.checklist_template.name, negishi.name ]
  end

  test "利用者が同じ名前で作った、巡回以外のテンプレートの計画は、名前を変えない" do
    monthly = ChecklistTemplate.create!(name: "月次", department: @section, inspection_type: "periodic", cycle: "monthly")
    custom = plan("常圧蒸留装置 計器日常点検", monthly)

    run_migration

    assert_equal "常圧蒸留装置 計器日常点検", custom.reload.name
  end
end
