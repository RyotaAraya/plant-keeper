require "test_helper"
require Rails.root.join("db/migrate/20260925020000_upgrade_checklist_template_items")

# カタログのテンプレートの項目を、判定基準・単位・許容範囲・選択肢・必須・区分つきの形に作り直す、既存環境への反映マイグレーション
class UpgradeChecklistTemplateItemsMigrationTest < ActiveSupport::TestCase
  setup do
    @department = create_department
    @equipment = create_equipment
  end

  def run_migration
    ActiveRecord::Migration.suppress_messages { UpgradeChecklistTemplateItems.new.up }
  end

  test "カタログと同じ名前のテンプレートの項目を作り直し、何度実行しても同じ。過去の点検の項目は内容を保ち、参照だけ外れる" do
    template = ChecklistTemplate.create!(name: "伝送器 月次点検", department: @department, inspection_type: "periodic", cycle: "monthly")
    old_item = template.checklist_template_items.create!(position: 1, content: "ゼロ点のずれが許容内であること", item_type: "check")
    inspection = Inspection.create!(user: create_user, equipment: @equipment, department: @department, checklist_template: template,
                                    inspection_type: "periodic", status: "approved", inspected_at: Time.current)
    recorded = inspection.inspection_items.create!(position: 1, content: old_item.content, item_type: "check", result: "good", checklist_template_item: old_item)

    2.times { run_migration }

    expected = ChecklistTemplateCatalog::TEMPLATES.find { |t| t[:name] == "伝送器 月次点検" }[:items].map { |entry| ChecklistTemplateCatalog.item_attributes(entry) }
    items = template.reload.checklist_template_items
    assert_equal expected.map { |item| item.values_at(:content, :item_type, :section, :criterion, :unit, :required) },
                 items.map { |item| [ item.content, item.item_type, item.section, item.criterion, item.unit, item.required ] }
    zero = items.find { |item| item.content.start_with?("ゼロ点") }
    assert_equal [ BigDecimal("3.92"), BigDecimal("4.08") ], [ zero.lower_limit, zero.upper_limit ]
    assert_equal (1..items.size).to_a, items.map(&:position)

    recorded.reload
    assert_equal [ "ゼロ点のずれが許容内であること", "good", nil ], [ recorded.content, recorded.result, recorded.checklist_template_item_id ]
  end

  test "選択式の選択肢を配列で持つ。利用者が作ったテンプレートには触れない" do
    annual = ChecklistTemplate.create!(name: "伝送器 年次点検", department: @department, inspection_type: "periodic")
    custom = ChecklistTemplate.create!(name: "独自の点検", department: @department, inspection_type: "periodic")
    custom.checklist_template_items.create!(position: 1, content: "独自の項目", item_type: "check")

    run_migration

    adjust = annual.checklist_template_items.find_by!(item_type: "choice")
    assert_equal [ "調整なし", "零点を調整", "スパンを調整", "零点・スパンを調整" ], adjust.options
    assert_equal [ "独自の項目" ], custom.checklist_template_items.map(&:content)
  end
end
