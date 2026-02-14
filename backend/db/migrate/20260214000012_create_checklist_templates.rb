class CreateChecklistTemplates < ActiveRecord::Migration[7.1]
  def change
    create_table :checklist_templates do |t|
      t.string :name, null: false
      t.references :department, null: false, foreign_key: true
      t.string :inspection_type, null: false

      t.timestamps
    end
  end
end
