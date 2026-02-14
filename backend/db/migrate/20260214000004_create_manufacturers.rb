class CreateManufacturers < ActiveRecord::Migration[7.1]
  def change
    create_table :manufacturers do |t|
      t.string :name, null: false
      t.text :former_names
      t.text :notes

      t.timestamps
    end
  end
end
