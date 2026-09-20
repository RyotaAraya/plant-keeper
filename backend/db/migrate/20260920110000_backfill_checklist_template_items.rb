# 点検項目が1件もないチェックリストテンプレートに、標準の点検項目を補充する（定義は db/data/checklist_template_items.rb）。
# シードでは3件にしか項目がなく、残りのテンプレートでは点検を始められなかったため、既存環境（stg・本番）にも流す。
# 名前が一致し、かつ項目が空のテンプレートだけが対象（項目を編集済み・追加済みのテンプレートには触れない）。何度実行しても同じ結果になる。
# モデルのコードには依存しない（バックフィルは生SQL）
require Rails.root.join("db/data/checklist_template_items")

class BackfillChecklistTemplateItems < ActiveRecord::Migration[8.0]
  def up
    ChecklistTemplateItemCatalog::ITEMS.each do |name, items|
      empty_template_ids(name).each do |template_id|
        items.each_with_index do |(content, item_type), index|
          execute <<~SQL.squish
            INSERT INTO checklist_template_items (checklist_template_id, position, content, item_type, created_at, updated_at)
            VALUES (#{template_id.to_i}, #{index + 1}, #{connection.quote(content)}, #{connection.quote(item_type)}, NOW(), NOW())
          SQL
        end
      end
    end
  end

  def down
    # 補充した項目は、利用者が編集した項目と区別できないため、ここでは消さない
  end

  private

  def empty_template_ids(name)
    select_values(<<~SQL.squish)
      SELECT t.id FROM checklist_templates t
      WHERE t.name = #{connection.quote(name)}
        AND NOT EXISTS (SELECT 1 FROM checklist_template_items i WHERE i.checklist_template_id = t.id)
    SQL
  end
end
