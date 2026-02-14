class AddInspectionItemForeignKeyToTroubles < ActiveRecord::Migration[7.1]
  def change
    add_foreign_key :troubles, :inspection_items, column: :inspection_item_id
    add_index :troubles, :inspection_item_id
  end
end
