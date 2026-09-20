# 点検で見た設備を、複数持てるようにする（運転員の巡回は、装置ごとではなく、いくつかの装置をまとめて1件で記録するため）。
# - inspection_equipments: 点検で見た設備の一覧。inspections.equipment_id（代表の設備）を必ず含む。既存の点検は代表の設備1つで作る
# - inspection_items.equipment_id: 項目の対象設備（複数の設備の点検で、不具合がどの設備のものか）。空は代表の設備
class CreateInspectionEquipments < ActiveRecord::Migration[8.0]
  def up
    create_table :inspection_equipments do |t|
      t.references :inspection, null: false, foreign_key: true
      t.references :equipment, null: false, foreign_key: true
      t.timestamps
    end
    add_index :inspection_equipments, [ :inspection_id, :equipment_id ], unique: true

    add_reference :inspection_items, :equipment, foreign_key: true

    execute <<~SQL.squish
      INSERT INTO inspection_equipments (inspection_id, equipment_id, created_at, updated_at)
      SELECT id, equipment_id, NOW(), NOW() FROM inspections
    SQL
  end

  def down
    remove_reference :inspection_items, :equipment, foreign_key: true
    drop_table :inspection_equipments
  end
end
