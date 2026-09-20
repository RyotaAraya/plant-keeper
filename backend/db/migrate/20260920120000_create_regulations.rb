# 法規区分（高圧ガス・ボイラーなど）と、その法定検査の周期、設備への適用。
# 設備がどの法規の対象かが、付属機器の点検周期・内容を決める起点になる
class CreateRegulations < ActiveRecord::Migration[8.0]
  def change
    create_table :regulations do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.string :law_name, null: false
      t.string :target, null: false, default: "equipment"
      t.text :description
      t.timestamps
    end
    add_index :regulations, :code, unique: true

    create_table :regulation_inspections do |t|
      t.references :regulation, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :interval_days, null: false
      t.string :basis, null: false, default: "statutory"
      t.string :note
      t.timestamps
    end

    create_table :equipment_regulations do |t|
      t.references :equipment, null: false, foreign_key: true
      t.references :regulation, null: false, foreign_key: true
      t.timestamps
    end
    add_index :equipment_regulations, [ :equipment_id, :regulation_id ], unique: true
  end
end
