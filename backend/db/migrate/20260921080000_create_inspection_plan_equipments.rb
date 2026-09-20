# 点検計画の対象設備を、複数持てるようにする（運転員の巡回の計画は、装置ごとではなく、いくつかの装置をまとめて1件にするため）。
# inspection_plans.equipment_id は代表の設備（先頭）で、対象の設備の全体（代表の設備を含む）は inspection_plan_equipments。
# 既存の計画（設備を対象にしたもの。基準器の校正計画は除く）は、代表の設備1行を作る
class CreateInspectionPlanEquipments < ActiveRecord::Migration[8.0]
  def up
    create_table :inspection_plan_equipments do |t|
      t.references :inspection_plan, null: false, foreign_key: true
      t.references :equipment, null: false, foreign_key: true
      t.timestamps
    end
    add_index :inspection_plan_equipments, [ :inspection_plan_id, :equipment_id ], unique: true, name: "index_inspection_plan_equipments_on_plan_and_equipment"

    execute <<~SQL.squish
      INSERT INTO inspection_plan_equipments (inspection_plan_id, equipment_id, created_at, updated_at)
      SELECT id, equipment_id, NOW(), NOW() FROM inspection_plans WHERE equipment_id IS NOT NULL
    SQL
  end

  def down
    drop_table :inspection_plan_equipments
  end
end
