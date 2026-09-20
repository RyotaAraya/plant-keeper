# 定期整備の作業（部署ごとに、どの設備・計器で何をするか）。点検の作業は、チェックリスト（定修点検）と点検記録に紐づく。
# チェックリストに周期（cycle）を持たせ、定修のチェックリストは点検計画には使わず、定期整備の作業から使う
class CreateMaintenanceTasks < ActiveRecord::Migration[8.0]
  def change
    create_table :maintenance_tasks do |t|
      t.references :scheduled_maintenance, null: false, foreign_key: true
      t.references :department, foreign_key: true
      t.references :equipment, null: false, foreign_key: true
      t.references :instrument, foreign_key: true
      t.references :checklist_template, foreign_key: true
      t.references :assigned_to, foreign_key: { to_table: :users }
      t.string :kind, null: false, default: "inspection"
      t.string :title, null: false
      t.string :status, null: false, default: "not_started"
      t.date :completed_on
      t.text :notes
      t.timestamps
    end
    add_index :maintenance_tasks, [ :scheduled_maintenance_id, :status ]

    add_reference :inspections, :maintenance_task, foreign_key: true
    add_column :checklist_templates, :cycle, :string
  end
end
