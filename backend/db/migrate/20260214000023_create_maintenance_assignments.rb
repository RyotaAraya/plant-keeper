class CreateMaintenanceAssignments < ActiveRecord::Migration[7.1]
  def change
    create_table :maintenance_assignments do |t|
      t.references :scheduled_maintenance, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :role, null: false, default: "member"

      t.timestamps
    end
  end
end
