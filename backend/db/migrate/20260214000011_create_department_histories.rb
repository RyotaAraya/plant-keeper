class CreateDepartmentHistories < ActiveRecord::Migration[7.1]
  def change
    create_table :department_histories do |t|
      t.references :user, null: false, foreign_key: true
      t.references :department, null: false, foreign_key: true
      t.date :started_on, null: false
      t.date :ended_on
      t.string :role_note

      t.timestamps
    end
  end
end
