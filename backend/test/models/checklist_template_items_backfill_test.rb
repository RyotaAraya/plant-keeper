require "test_helper"
require Rails.root.join("db/migrate/20260920110000_backfill_checklist_template_items")

# 項目が空のテンプレートにだけ標準の点検項目を補充するマイグレーション（既存環境への反映用）
class ChecklistTemplateItemsBackfillTest < ActiveSupport::TestCase
  ROUTINE = "計器日常点検チェックリスト"
  TANK = "タンク計器点検チェックリスト"

  setup do
    @department = create_department
  end

  test "カタログの内容は、種別が有効で、最後が特記事項になっている" do
    ChecklistTemplateItemCatalog::ITEMS.each do |name, items|
      assert items.all? { |content, type| content.present? && ChecklistTemplateItem.item_types.key?(type) }, name
      assert_equal [ "特記事項", "text" ], items.last, name
    end
  end

  test "項目が空のテンプレートに、カタログの項目が順番どおりに入る" do
    template = create_template(TANK)

    run_backfill

    items = template.checklist_template_items.reload
    assert_equal ChecklistTemplateItemCatalog::ITEMS.fetch(TANK), items.map { |i| [ i.content, i.item_type ] }
    assert_equal (1..items.size).to_a, items.map(&:position)
  end

  test "すでに項目があるテンプレートには触れない" do
    template = create_template(ROUTINE)
    template.checklist_template_items.create!(position: 1, content: "独自の項目", item_type: "check")

    run_backfill

    assert_equal [ "独自の項目" ], template.checklist_template_items.reload.map(&:content)
  end

  test "名前がカタログにないテンプレートには入れない" do
    template = create_template("独自チェックリスト")

    run_backfill

    assert_empty template.checklist_template_items.reload
  end

  test "何度実行しても項目は増えない" do
    template = create_template(TANK)

    run_backfill
    assert_no_difference -> { ChecklistTemplateItem.count } do
      run_backfill
    end
    assert_equal ChecklistTemplateItemCatalog::ITEMS.fetch(TANK).size, template.checklist_template_items.reload.size
  end

  private

  def create_template(name)
    ChecklistTemplate.create!(name: name, department: @department, inspection_type: "periodic")
  end

  def run_backfill
    ActiveRecord::Migration.suppress_messages { BackfillChecklistTemplateItems.new.up }
  end
end
