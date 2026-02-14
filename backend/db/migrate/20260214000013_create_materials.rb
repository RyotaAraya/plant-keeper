class CreateMaterials < ActiveRecord::Migration[7.1]
  def change
    create_table :materials do |t|
      t.references :manufacturer, foreign_key: true
      t.string :part_number, null: false
      t.string :normalized_part_number
      t.string :name, null: false
      t.text :description
      t.text :former_part_numbers
      t.string :availability, default: "catalog"
      t.string :category
      t.string :rating
      t.integer :lead_time_days
      t.boolean :is_hazardous, default: false
      t.string :hazard_note
      t.string :reorder_method, default: "reorder_point"
      t.integer :reorder_point
      t.integer :reorder_quantity

      t.timestamps
    end

    add_index :materials, :part_number
    add_index :materials, :normalized_part_number
  end
end
