class CreateMaterialAlternatives < ActiveRecord::Migration[7.1]
  def change
    create_table :material_alternatives do |t|
      t.references :material, null: false, foreign_key: true
      t.references :alternative_material, null: false, foreign_key: { to_table: :materials }
      t.string :notes

      t.timestamps
    end

    add_index :material_alternatives, [ :material_id, :alternative_material_id ], unique: true, name: "index_material_alternatives_uniqueness"
  end
end
