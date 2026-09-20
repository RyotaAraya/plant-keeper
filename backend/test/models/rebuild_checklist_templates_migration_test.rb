require "test_helper"
require Rails.root.join("db/migrate/20260920150100_rebuild_checklist_templates")

# チェックリストを「機器の種類 × 周期」に作り直す、既存環境への反映マイグレーション
class RebuildChecklistTemplatesMigrationTest < ActiveSupport::TestCase
  setup do
    @site = Site.create!(name: "川崎製油所")
    division = create_department(site: @site, name: "保全部")
    @section = create_department(site: @site, name: "計装保全課", level: "section", parent: division)
    @equipment = create_equipment(site: @site)
    @today = InspectionPlan.today
  end

  def old_template(name, type: "routine")
    ChecklistTemplate.create!(name: name, department: @section, inspection_type: type)
  end

  def plan(name, template, interval: 30, last: @today - 10)
    InspectionPlan.create!(name: name, equipment: @equipment, checklist_template: template, inspection_type: "periodic",
                           interval_days: interval, last_inspected_on: last, next_due_on: last + interval)
  end

  def run_migration
    ActiveRecord::Migration.suppress_messages { RebuildChecklistTemplates.new.up }
  end

  test "存在する拠点の新しいテンプレートを、項目つきで作り、何度実行しても増えない（部署が無い拠点には作らない）" do
    2.times { run_migration }

    kawasaki = ChecklistTemplateCatalog::TEMPLATES.select { |t| t[:site] == "川崎製油所" }
    assert_equal kawasaki.size, ChecklistTemplate.count
    template = ChecklistTemplate.find_by!(name: "遮断弁・インターロック 年次点検")
    assert_equal [ @section, "periodic", true ], [ template.department, template.inspection_type, template.is_active ]
    assert_equal ChecklistTemplateCatalog::TEMPLATES.find { |t| t[:name] == template.name }[:items],
                 template.checklist_template_items.map { |i| [ i.content, i.item_type ] }
    assert_equal (1..template.checklist_template_items.size).to_a, template.checklist_template_items.map(&:position)
    assert_nil ChecklistTemplate.find_by(name: "根岸 伝送器 巡回点検")
    assert_nil ChecklistTemplate.find_by(name: "堺 伝送器 巡回点検")
  end

  test "旧テンプレートは、消さずに廃止にし、過去の点検記録の参照は残る。利用者が作ったテンプレートには触れない" do
    old = old_template("計器日常点検チェックリスト")
    item = old.checklist_template_items.create!(position: 1, content: "伝送器の指示値を確認", item_type: "check")
    inspection = Inspection.create!(user: create_user, equipment: @equipment, department: @section, checklist_template: old,
                                    inspection_type: "routine", status: "approved", inspected_at: Time.current)
    inspection.inspection_items.create!(position: 1, content: item.content, item_type: "check", checklist_template_item: item)
    custom = old_template("独自チェックリスト")

    run_migration

    assert_not old.reload.is_active
    assert_equal old, inspection.reload.checklist_template
    assert_equal item, inspection.inspection_items.first.checklist_template_item
    assert custom.reload.is_active
  end

  test "旧テンプレートを使っていた点検計画を、置き換え先の新しいテンプレートに付け替える" do
    routine = plan("巡回", old_template("計器日常点検チェックリスト"))
    tank = plan("タンク", old_template("タンク計器点検チェックリスト", type: "periodic"))
    custom = plan("独自", old_template("独自チェックリスト"))

    run_migration

    assert_equal "伝送器 巡回点検", routine.reload.checklist_template.name
    assert_equal "タンク液面計 年次点検", tank.reload.checklist_template.name
    assert_equal "独自チェックリスト", custom.reload.checklist_template.name
  end

  test "デモの点検計画は、内容に合うテンプレート・名前・周期に直し、周期を変えたら次回期限を前回実施日から数え直す" do
    flow = plan("FT-301 流量伝送器 定期点検", old_template("調節弁定期点検チェックリスト", type: "periodic"), interval: 90, last: @today - 100)
    boiler = plan("ボイラー安全弁 定期点検", old_template("ボイラー安全弁点検チェックリスト", type: "periodic"), interval: 180, last: @today - 176)

    run_migration

    flow.reload
    assert_equal [ "伝送器 月次点検", "FT-301 流量伝送器 ゼロ点確認", 90 ], [ flow.checklist_template.name, flow.name, flow.interval_days ]
    boiler.reload
    assert_equal [ "安全弁 年次点検", "ボイラー安全弁 年次点検", 365, @today - 176 + 365 ], [ boiler.checklist_template.name, boiler.name, boiler.interval_days, boiler.next_due_on ]
  end

  test "置き換え先のない旧テンプレート（電気設備）の計画は付け替えず、置き換え先が作れないときも計画を消さない" do
    electric = plan("電気", old_template("電気設備日常点検チェックリスト"))
    negishi = plan("根岸の巡回", old_template("根岸 計器日常点検チェックリスト"))

    run_migration

    assert_equal "電気設備日常点検チェックリスト", electric.reload.checklist_template.name
    assert_equal "根岸 計器日常点検チェックリスト", negishi.reload.checklist_template.name # 根岸には計装保全課が無く、新しいテンプレートを作れない
  end
end
