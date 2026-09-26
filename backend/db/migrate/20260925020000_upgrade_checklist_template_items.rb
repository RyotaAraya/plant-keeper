# カタログ（db/data/checklist_templates.rb）のテンプレートの項目を、判定基準・単位・許容範囲・選択肢・必須・区分つきの形に作り直す。
# - 対象はカタログと同じ名前のテンプレートだけ（利用者が作ったテンプレートには触れない）。廃止済みのものも名前が同じなら作り直す
# - 過去の点検の項目は、内容・種別を自分で持っているため変わらない。テンプレートの項目への参照（checklist_template_item_id）だけ外す
# 何度実行しても同じ結果になる。モデルのコードには依存しない（生SQL）
require Rails.root.join("db/data/checklist_templates")

class UpgradeChecklistTemplateItems < ActiveRecord::Migration[8.0]
  def up
    ChecklistTemplateCatalog::TEMPLATES.each do |attrs|
      template_ids = select_values("SELECT id FROM checklist_templates WHERE name = #{connection.quote(attrs[:name])}")
      template_ids.each { |template_id| rebuild_items(template_id.to_i, attrs[:items]) }
    end
  end

  def down
    # 作り直した項目は、利用者の編集と区別できないため、ここでは戻さない
  end

  private

  def rebuild_items(template_id, items)
    execute <<~SQL.squish
      UPDATE inspection_items SET checklist_template_item_id = NULL
      WHERE checklist_template_item_id IN (SELECT id FROM checklist_template_items WHERE checklist_template_id = #{template_id})
    SQL
    execute "DELETE FROM checklist_template_items WHERE checklist_template_id = #{template_id}"

    items.each_with_index do |entry, index|
      item = ChecklistTemplateCatalog.item_attributes(entry)
      values = [
        template_id, index + 1, item[:content], item[:item_type], item[:section], item[:criterion], item[:unit],
        item[:lower_limit], item[:upper_limit], item[:options]&.to_json, item[:required]
      ].map { |value| value.is_a?(Integer) ? value : connection.quote(value) }
      execute <<~SQL.squish
        INSERT INTO checklist_template_items
          (checklist_template_id, position, content, item_type, section, criterion, unit, lower_limit, upper_limit, options, required, created_at, updated_at)
        VALUES (#{values.join(', ')}, NOW(), NOW())
      SQL
    end
  end
end
