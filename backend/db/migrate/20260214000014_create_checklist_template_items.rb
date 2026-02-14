class CreateChecklistTemplateItems < ActiveRecord::Migration[7.1]
  def change
    create_table :checklist_template_items do |t|
      t.references :checklist_template, null: false, foreign_key: true
      t.integer :position, null: false
      t.string :content, null: false
      t.string :item_type, null: false, default: "check"

      t.timestamps
    end
  end
end
