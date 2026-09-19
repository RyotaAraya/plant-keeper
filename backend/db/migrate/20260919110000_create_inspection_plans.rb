class CreateInspectionPlans < ActiveRecord::Migration[8.0]
  def change
    create_table :inspection_plans do |t|
      t.string :name, null: false
      t.references :equipment, null: false, foreign_key: true
      t.references :instrument, foreign_key: true
      t.references :checklist_template, foreign_key: true
      t.string :inspection_type, null: false
      t.integer :interval_days, null: false
      t.date :last_inspected_on
      t.date :next_due_on, null: false
      t.boolean :is_active, null: false, default: true
      t.timestamps
    end

    add_index :inspection_plans, :next_due_on
    add_check_constraint :inspection_plans, "interval_days > 0", name: "inspection_plans_interval_positive"

    # 点検記録がどの計画の実施かを持つ（計画なしの臨時点検は NULL）
    add_reference :inspections, :inspection_plan, foreign_key: true
  end
end
