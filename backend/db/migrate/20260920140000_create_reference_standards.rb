# 基準器（校正に使う圧力校正器・マルチテスタ・温度校正器など）の台帳と、メーカー校正の履歴、
# 点検で使った基準器（使用前の1点チェックつき）。基準器の年次校正は点検計画に載せる（計画の対象は設備か基準器のどちらか）
class CreateReferenceStandards < ActiveRecord::Migration[8.0]
  def change
    create_table :reference_standards do |t|
      t.references :site, null: false, foreign_key: true
      t.string :management_number, null: false
      t.string :name, null: false
      t.string :category, null: false, default: "other"
      t.string :model_number
      t.string :serial_number
      t.string :measuring_range
      t.string :accuracy
      t.string :location
      t.string :status, null: false, default: "usable"
      t.text :notes
      t.timestamps
    end
    add_index :reference_standards, :management_number, unique: true

    create_table :reference_standard_calibrations do |t|
      t.references :reference_standard, null: false, foreign_key: true
      t.date :performed_on, null: false
      t.string :performed_by, null: false
      t.string :certificate_number
      t.string :result, null: false, default: "pass"
      t.boolean :traceable, null: false, default: false
      t.date :valid_until, null: false
      t.text :notes
      t.timestamps
    end
    add_index :reference_standard_calibrations, [ :reference_standard_id, :performed_on ], name: "index_rs_calibrations_on_standard_and_performed_on"

    create_table :inspection_reference_standards do |t|
      t.references :inspection, null: false, foreign_key: true
      t.references :reference_standard, null: false, foreign_key: true
      t.boolean :pre_check_passed
      t.string :pre_check_note
      t.timestamps
    end
    add_index :inspection_reference_standards, [ :inspection_id, :reference_standard_id ], unique: true, name: "index_inspection_reference_standards_unique"

    add_reference :inspection_plans, :reference_standard, foreign_key: true
    change_column_null :inspection_plans, :equipment_id, true
    add_check_constraint :inspection_plans, "(equipment_id IS NOT NULL) <> (reference_standard_id IS NOT NULL)", name: "inspection_plans_one_target"
  end
end
