class CreateInspectionItems < ActiveRecord::Migration[7.1]
  def change
    create_table :inspection_items do |t|
      t.references :inspection, null: false, foreign_key: true
      t.references :checklist_template_item, foreign_key: true
      t.integer :position, null: false
      t.string :content, null: false
      t.string :item_type, null: false, default: "check"
      t.boolean :checked
      t.string :measured_value
      t.text :text_value
      t.boolean :has_defect, default: false
      t.references :instrument, foreign_key: true

      t.timestamps
    end
  end
end
