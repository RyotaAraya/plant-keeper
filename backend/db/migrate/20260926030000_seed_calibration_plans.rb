# 年次校正の点検計画（周期の見直しの候補を出す対象）のデモ用データを既存環境（stg・本番）に入れる（定義は db/data/calibration_history.rb の PLANS）。
# 同じ名前・計器の計画があれば触れない。計器・チェックリストが無い環境（空のDBなど）には作らない。
# 何度実行しても同じ結果になる。モデルのコードには依存しない（生SQL）
require Rails.root.join("db/data/calibration_history")

class SeedCalibrationPlans < ActiveRecord::Migration[8.0]
  def up
    today = Time.zone.today
    template_id = select_value("SELECT id FROM checklist_templates WHERE name = #{quote(CalibrationHistoryCatalog::PLAN_TEMPLATE)}")
    return unless template_id

    CalibrationHistoryCatalog::PLANS.each do |plan|
      instrument = select_one(<<~SQL.squish)
        SELECT instruments.id, instruments.equipment_id FROM instruments JOIN equipments ON equipments.id = instruments.equipment_id
        JOIN sites ON sites.id = equipments.site_id WHERE sites.name = #{quote(plan[:site])} AND instruments.tag_number = #{quote(plan[:tag])}
      SQL
      next unless instrument
      next if select_value("SELECT 1 FROM inspection_plans WHERE name = #{quote(plan[:name])} AND instrument_id = #{quote(instrument['id'])}")

      last = today - plan[:last_days_ago]
      plan_id = select_value(<<~SQL.squish)
        INSERT INTO inspection_plans (name, equipment_id, instrument_id, checklist_template_id, inspection_type, interval_days,
                                      last_inspected_on, next_due_on, is_active, created_at, updated_at)
        VALUES (#{quote(plan[:name])}, #{quote(instrument['equipment_id'])}, #{quote(instrument['id'])}, #{quote(template_id)}, 'periodic',
                #{quote(plan[:interval_days])}, #{quote(last)}, #{quote(last + plan[:interval_days])}, TRUE, NOW(), NOW())
        RETURNING id
      SQL
      # 計画の対象設備（代表の設備だけ。モデルの CoversEquipments が作る行と同じ）
      execute <<~SQL.squish
        INSERT INTO inspection_plan_equipments (inspection_plan_id, equipment_id, created_at, updated_at)
        VALUES (#{quote(plan_id)}, #{quote(instrument['equipment_id'])}, NOW(), NOW())
      SQL
    end
  end

  def down
    names = CalibrationHistoryCatalog::PLANS.map { |plan| quote(plan[:name]) }.join(", ")
    execute "DELETE FROM inspection_plan_equipments WHERE inspection_plan_id IN (SELECT id FROM inspection_plans WHERE name IN (#{names}))"
    execute "UPDATE inspections SET inspection_plan_id = NULL WHERE inspection_plan_id IN (SELECT id FROM inspection_plans WHERE name IN (#{names}))"
    execute "DELETE FROM inspection_plans WHERE name IN (#{names})"
  end

  private

  def quote(value) = connection.quote(value)
end
