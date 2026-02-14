class CreateInspections < ActiveRecord::Migration[7.1]
  def change
    create_table :inspections do |t|
      t.references :checklist_template, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :equipment, null: false, foreign_key: true
      t.references :instrument, foreign_key: true
      t.references :department, null: false, foreign_key: true
      t.string :inspection_type, null: false
      t.string :status, null: false, default: "draft"
      t.datetime :inspected_at, null: false
      t.text :notes

      t.timestamps
    end

    add_index :inspections, :status
    add_index :inspections, :inspection_type
  end
end
