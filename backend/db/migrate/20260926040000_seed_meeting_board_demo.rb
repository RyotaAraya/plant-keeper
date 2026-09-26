# 朝会・夕会ボードのデモ用データ（実施中の定期整備と作業、今日・明日が期限の点検計画）を既存環境（stg・本番）に入れる
# （定義は db/data/meeting_board.rb）。日付は実行した日を今日として決める。
# 同じ拠点・名前の定期整備、同じ名前・計器の計画があれば触れない。設備・計器・チェックリストが無い環境（空のDBなど）には作らない。
# 何度実行しても同じ結果になる。モデルのコードには依存しない（生SQL）
require Rails.root.join("db/data/meeting_board")

class SeedMeetingBoardDemo < ActiveRecord::Migration[8.0]
  def up
    today = Time.find_zone("Tokyo").today
    insert_maintenance(today)
    MeetingBoardCatalog::PLANS.each { |plan| insert_plan(plan, today) }
  end

  def down
    spec = MeetingBoardCatalog::MAINTENANCE
    maintenance_ids = <<~SQL.squish
      SELECT scheduled_maintenances.id FROM scheduled_maintenances JOIN sites ON sites.id = scheduled_maintenances.site_id
      WHERE sites.name = #{quote(spec[:site])} AND scheduled_maintenances.title = #{quote(spec[:title])}
    SQL
    execute "UPDATE inspections SET maintenance_task_id = NULL WHERE maintenance_task_id IN (SELECT id FROM maintenance_tasks WHERE scheduled_maintenance_id IN (#{maintenance_ids}))"
    execute "DELETE FROM maintenance_tasks WHERE scheduled_maintenance_id IN (#{maintenance_ids})"
    execute "DELETE FROM maintenance_assignments WHERE scheduled_maintenance_id IN (#{maintenance_ids})"
    execute "DELETE FROM scheduled_maintenance_equipments WHERE scheduled_maintenance_id IN (#{maintenance_ids})"
    execute "DELETE FROM scheduled_maintenances WHERE id IN (#{maintenance_ids})"

    names = MeetingBoardCatalog::PLANS.map { |plan| quote(plan[:name]) }.join(", ")
    execute "DELETE FROM inspection_plan_equipments WHERE inspection_plan_id IN (SELECT id FROM inspection_plans WHERE name IN (#{names}))"
    execute "UPDATE inspections SET inspection_plan_id = NULL WHERE inspection_plan_id IN (SELECT id FROM inspection_plans WHERE name IN (#{names}))"
    execute "DELETE FROM inspection_plans WHERE name IN (#{names})"
  end

  private

  def quote(value) = connection.quote(value)

  def insert_maintenance(today)
    spec = MeetingBoardCatalog::MAINTENANCE
    site_id = select_value("SELECT id FROM sites WHERE name = #{quote(spec[:site])}")
    equipment_id = site_id && select_value("SELECT id FROM equipments WHERE site_id = #{quote(site_id)} AND name = #{quote(spec[:equipment])}")
    return unless equipment_id
    return if select_value("SELECT 1 FROM scheduled_maintenances WHERE site_id = #{quote(site_id)} AND title = #{quote(spec[:title])}")

    started = today + spec[:start_days]
    maintenance_id = select_value(<<~SQL.squish)
      INSERT INTO scheduled_maintenances (site_id, title, description, status, planned_start_on, planned_end_on, actual_start_on, created_at, updated_at)
      VALUES (#{quote(site_id)}, #{quote(spec[:title])}, #{quote(spec[:description])}, 'in_progress', #{quote(started)},
              #{quote(today + spec[:end_days])}, #{quote(started)}, NOW(), NOW())
      RETURNING id
    SQL
    execute <<~SQL.squish
      INSERT INTO scheduled_maintenance_equipments (scheduled_maintenance_id, equipment_id, created_at, updated_at)
      VALUES (#{quote(maintenance_id)}, #{quote(equipment_id)}, NOW(), NOW())
    SQL
    MeetingBoardCatalog::TASKS.each { |task| insert_task(maintenance_id, site_id, equipment_id, task, today) }
  end

  # 計器・チェックリスト・部署・担当者が見つからないときは、その値を空にせず作業ごと作らない（定義と違うデモにしない）
  def insert_task(maintenance_id, site_id, equipment_id, task, today)
    columns = { scheduled_maintenance_id: maintenance_id, equipment_id: equipment_id, kind: task[:kind], status: task[:status], notes: task[:notes],
                completed_on: task[:completed_days] && today + task[:completed_days] }
    if task[:tag]
      columns[:instrument_id] = select_value("SELECT id FROM instruments WHERE equipment_id = #{quote(equipment_id)} AND tag_number = #{quote(task[:tag])}")
      columns[:checklist_template_id] = select_value("SELECT id FROM checklist_templates WHERE name = #{quote(task[:template])} AND is_active ORDER BY id LIMIT 1")
      return unless columns[:instrument_id] && columns[:checklist_template_id]

      columns[:title] = "#{task[:tag]} #{task[:template]}" # MaintenanceTask#fill_title と同じ
    else
      columns[:title] = task[:title]
    end
    if task[:department]
      columns[:department_id] = select_value("SELECT id FROM departments WHERE site_id = #{quote(site_id)} AND name = #{quote(task[:department])}")
      return unless columns[:department_id]
    end
    if task[:assigned]
      columns[:assigned_to_id] = select_value("SELECT id FROM users WHERE email = #{quote(task[:assigned])}")
      return unless columns[:assigned_to_id]
    end
    execute <<~SQL.squish
      INSERT INTO maintenance_tasks (#{columns.keys.join(', ')}, created_at, updated_at)
      VALUES (#{columns.values.map { |value| quote(value) }.join(', ')}, NOW(), NOW())
    SQL
  end

  def insert_plan(plan, today)
    instrument = select_one(<<~SQL.squish)
      SELECT instruments.id, instruments.equipment_id FROM instruments JOIN equipments ON equipments.id = instruments.equipment_id
      JOIN sites ON sites.id = equipments.site_id WHERE sites.name = #{quote(plan[:site])} AND instruments.tag_number = #{quote(plan[:tag])}
    SQL
    template_id = select_value("SELECT id FROM checklist_templates WHERE name = #{quote(plan[:template])} AND is_active ORDER BY id LIMIT 1")
    return unless instrument && template_id
    return if select_value("SELECT 1 FROM inspection_plans WHERE name = #{quote(plan[:name])} AND instrument_id = #{quote(instrument['id'])}")

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
