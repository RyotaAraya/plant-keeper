# 定期整備を「親」にする: 対象設備を複数持ち（中間テーブル）、拠点・予定/実績の期間・検収を持つ。
# 旧の equipment_id / scheduled_date / completed_date は、使わなくなるが NULL可にして残す（次のリリースで削除。
# デプロイ中の旧コードが、既存の行を読めるようにするため）。既存の行の移行は BackfillScheduledMaintenanceParents
class RestructureScheduledMaintenances < ActiveRecord::Migration[8.0]
  def change
    create_table :scheduled_maintenance_equipments do |t|
      t.references :scheduled_maintenance, null: false, foreign_key: true
      t.references :equipment, null: false, foreign_key: true
      t.timestamps
    end
    add_index :scheduled_maintenance_equipments, [ :scheduled_maintenance_id, :equipment_id ], unique: true, name: "index_sm_equipments_on_maintenance_and_equipment"

    change_table :scheduled_maintenances, bulk: true do |t|
      t.references :site, foreign_key: true
      t.date :planned_start_on
      t.date :planned_end_on
      t.date :actual_start_on
      t.date :actual_end_on
      t.date :accepted_on
      t.references :accepted_by, foreign_key: { to_table: :users }
      t.string :acceptance_result
      t.text :acceptance_notes
    end
    add_index :scheduled_maintenances, :planned_start_on

    change_column_null :scheduled_maintenances, :equipment_id, true
    change_column_null :scheduled_maintenances, :scheduled_date, true
  end
end
