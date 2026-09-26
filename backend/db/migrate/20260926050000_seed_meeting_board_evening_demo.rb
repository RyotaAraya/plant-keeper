# 朝会・夕会ボードの夕会のデモ用データ（今日の点検と、今日の対応記録）を既存環境（stg・本番）に入れる
# （定義は db/data/meeting_board.rb の INSPECTIONS・RESPONSES）。時刻は実行した日の「今から何時間前か」（今日の0時より前にはしない）。
# 点検は SeedMeetingBoardDemo が作った定期整備の作業から実施したもので、提出した点検の作業は完了日を点検日にする
# （アプリで点検が下書きを出ると、作業が完了して完了日が点検日になるのと同じ）。
# 同じ作業・備考の点検、同じトラブル・人・内容の対応記録があれば触れない。定期整備・トラブル・ユーザが無い環境には作らない。
# 何度実行しても同じ結果になる。モデルのコードには依存しない（生SQL）。
# down は入れた点検・対応記録を消す（作業は完了のまま。完了日は戻さない）
require Rails.root.join("db/data/meeting_board")

class SeedMeetingBoardEveningDemo < ActiveRecord::Migration[8.0]
  def up
    now = Time.find_zone("Tokyo").now
    MeetingBoardCatalog::INSPECTIONS.each { |spec| insert_inspection(spec, now) }
    MeetingBoardCatalog::RESPONSES.each { |spec| insert_response(spec, now) }
  end

  def down
    MeetingBoardCatalog::INSPECTIONS.each do |spec|
      ids = "SELECT id FROM inspections WHERE maintenance_task_id IN (#{task_ids_sql(spec)}) AND notes = #{quote(spec[:notes])}"
      execute "DELETE FROM inspection_equipments WHERE inspection_id IN (#{ids})"
      execute "DELETE FROM inspections WHERE id IN (#{ids})"
    end
    MeetingBoardCatalog::RESPONSES.each do |spec|
      execute "DELETE FROM trouble_responses WHERE description = #{quote(spec[:description])}"
    end
  end

  private

  def quote(value) = connection.quote(value)

  # デモの定期整備の、計器のタグ番号の作業
  def task_ids_sql(spec)
    maintenance = MeetingBoardCatalog::MAINTENANCE
    <<~SQL.squish
      SELECT maintenance_tasks.id FROM maintenance_tasks
      JOIN scheduled_maintenances ON scheduled_maintenances.id = maintenance_tasks.scheduled_maintenance_id
      JOIN sites ON sites.id = scheduled_maintenances.site_id
      JOIN instruments ON instruments.id = maintenance_tasks.instrument_id
      WHERE sites.name = #{quote(maintenance[:site])} AND scheduled_maintenances.title = #{quote(maintenance[:title])}
        AND instruments.tag_number = #{quote(spec[:task_tag])}
    SQL
  end

  def insert_inspection(spec, now)
    task = select_one(<<~SQL.squish)
      SELECT maintenance_tasks.id, maintenance_tasks.equipment_id, maintenance_tasks.instrument_id, maintenance_tasks.checklist_template_id,
             scheduled_maintenances.site_id
      FROM maintenance_tasks JOIN scheduled_maintenances ON scheduled_maintenances.id = maintenance_tasks.scheduled_maintenance_id
      WHERE maintenance_tasks.id IN (#{task_ids_sql(spec)}) LIMIT 1
    SQL
    return unless task
    return if select_value("SELECT 1 FROM inspections WHERE maintenance_task_id = #{quote(task['id'])} AND notes = #{quote(spec[:notes])}")

    user_id = select_value("SELECT id FROM users WHERE email = #{quote(spec[:user])}")
    department_id = select_value("SELECT id FROM departments WHERE site_id = #{quote(task['site_id'])} AND name = #{quote(spec[:department])}")
    return unless user_id && department_id

    inspected_at = MeetingBoardCatalog.today_at(now, spec[:hours_ago])
    inspection_id = select_value(<<~SQL.squish)
      INSERT INTO inspections (user_id, department_id, equipment_id, instrument_id, checklist_template_id, maintenance_task_id,
                               inspection_type, status, inspected_at, notes, created_at, updated_at)
      VALUES (#{quote(user_id)}, #{quote(department_id)}, #{quote(task['equipment_id'])}, #{quote(task['instrument_id'])},
              #{quote(task['checklist_template_id'])}, #{quote(task['id'])}, 'periodic', #{quote(spec[:status])}, #{quote(inspected_at)},
              #{quote(spec[:notes])}, NOW(), NOW())
      RETURNING id
    SQL
    # 点検の対象設備（代表の設備だけ。モデルの CoversEquipments が作る行と同じ）
    execute <<~SQL.squish
      INSERT INTO inspection_equipments (inspection_id, equipment_id, created_at, updated_at)
      VALUES (#{quote(inspection_id)}, #{quote(task['equipment_id'])}, NOW(), NOW())
    SQL
    return if spec[:status] == "draft"

    execute <<~SQL.squish
      UPDATE maintenance_tasks SET status = 'completed', completed_on = #{quote(inspected_at.to_date)}, updated_at = NOW()
      WHERE id = #{quote(task['id'])}
    SQL
  end

  def insert_response(spec, now)
    trouble_id = select_value(<<~SQL.squish)
      SELECT troubles.id FROM troubles JOIN equipments ON equipments.id = troubles.equipment_id JOIN sites ON sites.id = equipments.site_id
      WHERE sites.name = #{quote(spec[:site])} AND troubles.title = #{quote(spec[:trouble])} ORDER BY troubles.id LIMIT 1
    SQL
    user_id = select_value("SELECT id FROM users WHERE email = #{quote(spec[:user])}")
    return unless trouble_id && user_id
    return if select_value("SELECT 1 FROM trouble_responses WHERE trouble_id = #{quote(trouble_id)} AND user_id = #{quote(user_id)} AND description = #{quote(spec[:description])}")

    execute <<~SQL.squish
      INSERT INTO trouble_responses (trouble_id, user_id, response_type, description, responded_at, created_at, updated_at)
      VALUES (#{quote(trouble_id)}, #{quote(user_id)}, #{quote(spec[:response_type])}, #{quote(spec[:description])},
              #{quote(MeetingBoardCatalog.today_at(now, spec[:hours_ago]))}, NOW(), NOW())
    SQL
  end
end
