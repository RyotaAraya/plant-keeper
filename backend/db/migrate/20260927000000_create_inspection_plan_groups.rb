# 点検計画の親「点検のまとまり」を作り、既存の点検計画をすべてどれかのまとまりに入れる。
# まとめ方は InspectionPlanGroup.default_for と同じ規則（拠点 × チェックリストの名前。基準器の校正は「拠点名 基準器の年次校正」、
# チェックリストのない計画は「チェックリストなしの点検」）。担当部署はチェックリストの部署（計画と同じ拠点のときだけ）、
# 既定の周期は、まとめた計画で最も多い周期。モデルのコードには依存しない（生SQL）
require Rails.root.join("db/data/inspection_plan_groups")

class CreateInspectionPlanGroups < ActiveRecord::Migration[8.0]
  def up
    create_table :inspection_plan_groups do |t|
      t.references :site, null: false, foreign_key: true
      t.string :name, null: false
      t.references :department, foreign_key: true
      t.references :regulation, foreign_key: true
      t.integer :default_interval_days
      t.boolean :is_active, null: false, default: true
      t.timestamps
      t.index [ :site_id, :name ], unique: true
      t.check_constraint "default_interval_days IS NULL OR default_interval_days > 0", name: "inspection_plan_groups_interval_positive"
    end
    add_reference :inspection_plans, :inspection_plan_group, foreign_key: true

    backfill
    apply_demo_regulations
    change_column_null :inspection_plans, :inspection_plan_group_id, false
  end

  def down
    remove_reference :inspection_plans, :inspection_plan_group, foreign_key: true
    drop_table :inspection_plan_groups
  end

  private

  def backfill
    plans = select_all(<<~SQL.squish).to_a
      SELECT inspection_plans.id, inspection_plans.interval_days, inspection_plans.reference_standard_id,
             COALESCE(equipments.site_id, reference_standards.site_id) AS site_id, sites.name AS site_name,
             checklist_templates.name AS template_name, departments.id AS department_id, departments.site_id AS department_site_id
      FROM inspection_plans
      LEFT JOIN equipments ON equipments.id = inspection_plans.equipment_id
      LEFT JOIN reference_standards ON reference_standards.id = inspection_plans.reference_standard_id
      JOIN sites ON sites.id = COALESCE(equipments.site_id, reference_standards.site_id)
      LEFT JOIN checklist_templates ON checklist_templates.id = inspection_plans.checklist_template_id
      LEFT JOIN departments ON departments.id = checklist_templates.department_id
      WHERE inspection_plans.inspection_plan_group_id IS NULL
      ORDER BY inspection_plans.id
    SQL

    plans.group_by { |plan| [ plan["site_id"], group_name(plan) ] }.each do |(site_id, name), members|
      group_id = select_value("SELECT id FROM inspection_plan_groups WHERE site_id = #{quote(site_id)} AND name = #{quote(name)}")
      group_id ||= insert_group(site_id, name, members)
      execute "UPDATE inspection_plans SET inspection_plan_group_id = #{quote(group_id)} WHERE id IN (#{members.map { |plan| quote(plan['id']) }.join(', ')})"
    end
  end

  def group_name(plan)
    if plan["reference_standard_id"] then "#{plan['site_name']} 基準器の年次校正"
    elsif plan["template_name"] then plan["template_name"]
    else "チェックリストなしの点検"
    end
  end

  # quote(nil) はマイグレーションの中では空文字になる（テーブル名として扱われる）ため、NULL になり得る値は connection.quote で書く
  def insert_group(site_id, name, members)
    department = members.find { |plan| plan["department_id"] && plan["department_site_id"].to_i == site_id.to_i }&.dig("department_id")
    interval = members.map { |plan| plan["interval_days"].to_i }.tally.max_by { |days, count| [ count, -days ] }.first
    select_value(<<~SQL.squish)
      INSERT INTO inspection_plan_groups (site_id, name, department_id, default_interval_days, is_active, created_at, updated_at)
      VALUES (#{quote(site_id)}, #{quote(name)}, #{connection.quote(department)}, #{quote(interval)}, TRUE, NOW(), NOW())
      RETURNING id
    SQL
  end

  # デモの法規区分（まだ法規区分のないまとまりだけ）
  def apply_demo_regulations
    InspectionPlanGroupCatalog::REGULATIONS.each do |name, code|
      regulation_id = select_value("SELECT id FROM regulations WHERE code = #{quote(code)}")
      next unless regulation_id

      execute "UPDATE inspection_plan_groups SET regulation_id = #{quote(regulation_id)} WHERE name = #{quote(name)} AND regulation_id IS NULL"
    end
  end
end
