# トラブルの出所（手入力 / 点検の不具合 / 機器の診断）と、機器の診断から作ったときの元の診断。
# 既存のトラブルは、点検の項目から作ったものを「点検」、ほかを「手入力」にする
class AddSourceToTroubles < ActiveRecord::Migration[8.0]
  def up
    add_column :troubles, :source, :string, null: false, default: "manual"
    add_reference :troubles, :instrument_diagnostic, foreign_key: true, null: true
    add_check_constraint :troubles, "source IN ('manual', 'inspection', 'device_diagnostic')", name: "troubles_source"
    add_check_constraint :troubles, "(source = 'device_diagnostic') = (instrument_diagnostic_id IS NOT NULL)", name: "troubles_diagnostic_source"
    execute "UPDATE troubles SET source = 'inspection' WHERE inspection_item_id IS NOT NULL"
  end

  def down
    remove_check_constraint :troubles, name: "troubles_diagnostic_source"
    remove_check_constraint :troubles, name: "troubles_source"
    remove_reference :troubles, :instrument_diagnostic, foreign_key: true
    remove_column :troubles, :source
  end
end
