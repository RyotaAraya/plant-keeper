class CreateEquipments < ActiveRecord::Migration[7.1]
  def change
    create_table :equipments do |t|
      t.string :name, null: false
      t.text :description
      t.references :site, null: false, foreign_key: true

      t.timestamps
    end
  end
end
