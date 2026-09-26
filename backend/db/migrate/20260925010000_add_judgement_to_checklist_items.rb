# チェックリストの項目に、判定基準・測定の単位と許容範囲・選択肢・必須・区分を持たせ、
# 点検の項目に判定（良好／不具合あり／該当なし）と、実施した時点の基準（テンプレートからの写し）を持たせる。
# 既存の点検の項目の判定は、不具合あり → defect、確認済み（checked）→ good、それ以外は未判定にする。
# checked は使わなくなるが、切り替え中の互換のため残す（削除は次のリリース）
class AddJudgementToChecklistItems < ActiveRecord::Migration[8.0]
  COLUMNS = lambda do |t|
    t.string :section
    t.string :criterion
    t.string :unit
    t.decimal :lower_limit, precision: 14, scale: 4
    t.decimal :upper_limit, precision: 14, scale: 4
    t.jsonb :options
    t.boolean :required, default: false, null: false
  end

  def up
    change_table(:checklist_template_items, &COLUMNS)
    change_table(:inspection_items, &COLUMNS)
    add_column :inspection_items, :result, :string

    execute <<~SQL.squish
      UPDATE inspection_items
      SET result = CASE WHEN has_defect THEN 'defect' WHEN item_type = 'check' AND checked THEN 'good' END
    SQL
  end

  def down
    remove_column :inspection_items, :result
    %i[checklist_template_items inspection_items].each do |table|
      remove_columns table, :section, :criterion, :unit, :lower_limit, :upper_limit, :options, :required
    end
  end
end
