class CreateScheduledMaintenances < ActiveRecord::Migration[7.1]
  def change
    create_table :scheduled_maintenances do |t|
      t.references :equipment, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.date :scheduled_date, null: false
      t.date :completed_date
      t.string :status, null: false, default: "planned"
      t.text :used_materials

      t.timestamps
    end

    add_index :scheduled_maintenances, :status
    add_index :scheduled_maintenances, :scheduled_date
  end
end
