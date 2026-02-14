class CreateServices < ActiveRecord::Migration[7.1]
  def change
    create_table :services do |t|
      t.string :name, null: false
      t.string :temperature
      t.string :pressure
      t.string :hazard_level
      t.text :hazard_description

      t.timestamps
    end
  end
end
