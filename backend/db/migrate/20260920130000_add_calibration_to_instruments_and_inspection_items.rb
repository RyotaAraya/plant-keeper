# 計器に校正の条件（範囲・許容差・出力特性・DCS換算）とテレメータ・取引用のフラグを持たせ、
# 点検項目に5点校正の記録（calibration_data）とその判定（calibration_result）を持たせる。
# 記録には校正時の条件（snapshot）も保存するため、あとで計器の設定を変えても過去の記録は変わらない
class AddCalibrationToInstrumentsAndInspectionItems < ActiveRecord::Migration[8.0]
  def change
    change_table :instruments, bulk: true do |t|
      t.decimal :range_lower, precision: 14, scale: 4
      t.decimal :range_upper, precision: 14, scale: 4
      t.string :range_unit
      t.string :output_characteristic, null: false, default: "linear"
      t.string :dcs_characteristic, null: false, default: "linear"
      t.decimal :dcs_range_lower, precision: 14, scale: 4
      t.decimal :dcs_range_upper, precision: 14, scale: 4
      t.string :dcs_range_unit
      t.decimal :tolerance_percent, precision: 6, scale: 3
      t.string :tolerance_basis
      t.boolean :telemetry, null: false, default: false
      t.boolean :custody_transfer, null: false, default: false
    end

    change_table :inspection_items, bulk: true do |t|
      t.jsonb :calibration_data
      t.string :calibration_result
    end
  end
end
