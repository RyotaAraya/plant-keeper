class CreateDepartments < ActiveRecord::Migration[7.1]
  def change
    create_table :departments do |t|
      t.string :name, null: false
      t.string :department_type, null: false
      t.references :site, foreign_key: true

      t.timestamps
    end

    add_index :departments, :department_type
  end
end
