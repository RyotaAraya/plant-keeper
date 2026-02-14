class CreateEquipmentAssignments < ActiveRecord::Migration[7.1]
  def change
    create_table :equipment_assignments do |t|
      t.references :user, null: false, foreign_key: true
      t.references :equipment, null: false, foreign_key: true
      t.string :role
      t.date :started_on, null: false
      t.date :ended_on

      t.timestamps
    end
  end
end
