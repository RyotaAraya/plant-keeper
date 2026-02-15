class CreateAuditLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :audit_logs do |t|
      t.references :user, foreign_key: true
      t.string :action, null: false
      t.string :auditable_type, null: false
      t.bigint :auditable_id, null: false
      t.jsonb :changes_json, default: {}
      t.string :ip_address
      t.datetime :performed_at, null: false

      t.datetime :created_at, null: false
    end

    add_index :audit_logs, [ :auditable_type, :auditable_id ]
    add_index :audit_logs, :action
    add_index :audit_logs, :performed_at
  end
end
