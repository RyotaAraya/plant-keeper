# 定期整備の系列（繰り返しのまとまり。例: A号ボイラー整備）と、設備ごとの周期（ボイラー24か月、発電機48か月）。
# 系列の定期整備から「次回を作る」とき、周期が来た設備を自動で対象にするために使う
class CreateMaintenanceSeries < ActiveRecord::Migration[8.0]
  def change
    create_table :maintenance_series do |t|
      t.references :site, null: false, foreign_key: true
      t.string :name, null: false
      t.text :notes
      t.timestamps
    end

    create_table :maintenance_series_equipments do |t|
      t.references :maintenance_series, null: false, foreign_key: true
      t.references :equipment, null: false, foreign_key: true
      t.integer :interval_months, null: false
      t.timestamps
    end
    add_index :maintenance_series_equipments, [ :maintenance_series_id, :equipment_id ], unique: true, name: "index_ms_equipments_on_series_and_equipment"
    add_check_constraint :maintenance_series_equipments, "interval_months > 0", name: "maintenance_series_equipments_interval_positive"

    add_reference :scheduled_maintenances, :maintenance_series, foreign_key: true
  end
end
