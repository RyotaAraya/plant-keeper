class SplitUserRole < ActiveRecord::Migration[7.2]
  def up
    add_column :users, :employment_type, :string, null: false, default: "employee"
    add_column :users, :system_role, :string, null: false, default: "member"
    add_column :users, :company, :string

    # 既存データの移行
    execute <<~SQL
      UPDATE users SET system_role = 'admin', employment_type = 'employee' WHERE role = 'admin';
      UPDATE users SET system_role = 'supervisor', employment_type = 'employee' WHERE role = 'supervisor';
      UPDATE users SET system_role = 'member', employment_type = 'employee' WHERE role = 'worker';
      UPDATE users SET system_role = 'member', employment_type = 'contractor' WHERE role = 'contractor';
      UPDATE users SET system_role = 'member', employment_type = 'employee' WHERE role = 'maintenance';
      UPDATE users SET system_role = 'member', employment_type = 'employee' WHERE role = 'environment';
    SQL

    remove_index :users, :role
    remove_column :users, :role

    add_index :users, :employment_type
    add_index :users, :system_role
  end

  def down
    add_column :users, :role, :string, null: false, default: "worker"

    execute <<~SQL
      UPDATE users SET role = 'admin' WHERE system_role = 'admin';
      UPDATE users SET role = 'supervisor' WHERE system_role = 'supervisor';
      UPDATE users SET role = 'contractor' WHERE employment_type = 'contractor';
      UPDATE users SET role = 'worker' WHERE system_role = 'member' AND employment_type != 'contractor';
    SQL

    add_index :users, :role

    remove_index :users, :employment_type
    remove_index :users, :system_role
    remove_column :users, :employment_type
    remove_column :users, :system_role
    remove_column :users, :company
  end
end
