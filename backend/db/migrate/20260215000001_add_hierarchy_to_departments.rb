class AddHierarchyToDepartments < ActiveRecord::Migration[7.1]
  def change
    add_reference :departments, :parent, foreign_key: { to_table: :departments }, null: true
    add_column :departments, :level, :string, null: false, default: 'section'
    add_index :departments, :level
  end
end
