# 機器の診断をトラブル・点検計画に反映するデモを既存環境（stg・本番）に入れる（シードは db/seeds/23_device_diagnostics.rb）。
# 1. 診断のある計器の点検計画（定義は db/data/device_diagnostics.rb の PLANS。前倒しの候補と、自動のトラブルの担当部署のデモ）。
#    同じ計器・名前の計画があれば作らない。まとまりは拠点 × チェックリストの名前で探し、なければ InspectionPlanGroup.default_for と同じ規則で作る
# 2. いま故障（F）の計器に、診断から作ったトラブル（DiagnosticTrouble と同じ内容）。未解決の同じ出所のトラブルがあれば作らない
# 拠点・計器・チェックリストが無い環境では、そのデモを飛ばす。何度実行しても同じ結果になる。モデルのコードには依存しない（生SQL）
require Rails.root.join("db/data/device_diagnostics")

class SeedDiagnosticTroubleDemo < ActiveRecord::Migration[8.0]
  def up
    site_id = select_value("SELECT id FROM sites WHERE name = #{quote(DeviceDiagnosticCatalog::SITE)}")
    seed_plans(site_id) if site_id
    seed_troubles
  end

  def down
    execute <<~SQL.squish
      DELETE FROM audit_logs WHERE auditable_type = 'Trouble'
        AND auditable_id IN (SELECT id FROM troubles WHERE source = 'device_diagnostic')
    SQL
    execute "DELETE FROM troubles WHERE source = 'device_diagnostic'"
    DeviceDiagnosticCatalog::PLANS.each do |spec|
      # 点検の記録がある計画は残す
      plan_ids = <<~SQL.squish
        SELECT id FROM inspection_plans WHERE name = #{quote(spec[:name])}
          AND NOT EXISTS (SELECT 1 FROM inspections WHERE inspections.inspection_plan_id = inspection_plans.id)
      SQL
      execute "DELETE FROM inspection_plan_equipments WHERE inspection_plan_id IN (#{plan_ids})"
      execute "DELETE FROM inspection_plans WHERE id IN (#{plan_ids})"
    end
  end

  private

  def seed_plans(site_id)
    today = Time.current.in_time_zone("Tokyo").to_date
    DeviceDiagnosticCatalog::PLANS.each do |spec|
      instrument = select_one(<<~SQL.squish)
        SELECT instruments.id, instruments.equipment_id FROM instruments JOIN equipments ON equipments.id = instruments.equipment_id
        WHERE equipments.site_id = #{quote(site_id)} AND instruments.tag_number = #{quote(spec[:tag])}
      SQL
      template = select_one(<<~SQL.squish)
        SELECT checklist_templates.id, checklist_templates.department_id, departments.site_id FROM checklist_templates
        JOIN departments ON departments.id = checklist_templates.department_id
        WHERE checklist_templates.name = #{quote(spec[:template])} AND checklist_templates.is_active ORDER BY checklist_templates.id LIMIT 1
      SQL
      next unless instrument && template
      next if select_value("SELECT 1 FROM inspection_plans WHERE instrument_id = #{quote(instrument['id'])} AND name = #{quote(spec[:name])}")

      group_id = select_value("SELECT id FROM inspection_plan_groups WHERE site_id = #{quote(site_id)} AND name = #{quote(spec[:template])}")
      group_id ||= select_value(<<~SQL.squish)
        INSERT INTO inspection_plan_groups (site_id, name, department_id, default_interval_days, created_at, updated_at)
        VALUES (#{quote(site_id)}, #{quote(spec[:template])}, #{quote(template['site_id'] == site_id ? template['department_id'] : nil)},
                #{quote(spec[:interval])}, NOW(), NOW())
        RETURNING id
      SQL
      last = today - spec[:last_days_ago]
      plan_id = select_value(<<~SQL.squish)
        INSERT INTO inspection_plans (name, equipment_id, instrument_id, checklist_template_id, inspection_type, interval_days,
                                      last_inspected_on, next_due_on, inspection_plan_group_id, created_at, updated_at)
        VALUES (#{quote(spec[:name])}, #{quote(instrument['equipment_id'])}, #{quote(instrument['id'])}, #{quote(template['id'])}, 'periodic',
                #{quote(spec[:interval])}, #{quote(last)}, #{quote(last + spec[:interval])}, #{quote(group_id)}, NOW(), NOW())
        RETURNING id
      SQL
      execute <<~SQL.squish
        INSERT INTO inspection_plan_equipments (inspection_plan_id, equipment_id, created_at, updated_at)
        VALUES (#{quote(plan_id)}, #{quote(instrument['equipment_id'])}, NOW(), NOW())
      SQL
    end
  end

  # DiagnosticTrouble.create_for と同じ内容（題名・説明・優先度・報告者・監査ログ）。元の診断は、計器の最新の診断
  def seed_troubles
    rows = select_all(<<~SQL.squish)
      SELECT DISTINCT ON (instruments.id) instruments.id AS instrument_id, instruments.tag_number, instruments.equipment_id,
             d.id AS diagnostic_id, d.code, d.message, d.occurred_at, t.name AS token_name, t.created_by_id
      FROM instruments
      JOIN instrument_diagnostics d ON d.instrument_id = instruments.id
      JOIN integration_tokens t ON t.id = d.integration_token_id
      WHERE instruments.diagnostic_status = 'failure'
      ORDER BY instruments.id, d.occurred_at DESC, d.id DESC
    SQL
    rows.each do |row|
      next if select_value(<<~SQL.squish)
        SELECT 1 FROM troubles WHERE source = 'device_diagnostic' AND instrument_id = #{quote(row['instrument_id'])}
          AND status IN ('open', 'in_progress', 'deferred')
      SQL

      occurred_at = Time.find_zone("UTC").parse(row["occurred_at"].to_s).in_time_zone("Tokyo")
      title = "#{row['tag_number']} 機器の診断で故障#{"（#{row['code']}）" if row['code'].present?}"
      description = [
        "機器管理システム（#{row['token_name']}）から、故障（F）の診断を受け取りました。",
        ("内容: #{row['message']}" if row["message"].present?),
        ("コード: #{row['code']}" if row["code"].present?),
        "発生日時: #{occurred_at.strftime('%Y-%m-%d %H:%M')}"
      ].compact.join("\n")
      site_id = select_value("SELECT site_id FROM equipments WHERE id = #{quote(row['equipment_id'])}")
      # 説明の改行を残すため squish しない
      trouble_id = select_value(<<~SQL)
        INSERT INTO troubles (source, instrument_diagnostic_id, equipment_id, instrument_id, reported_by_id, title, description, status, priority,
                              reported_at, created_at, updated_at)
        VALUES ('device_diagnostic', #{quote(row['diagnostic_id'])}, #{quote(row['equipment_id'])}, #{quote(row['instrument_id'])},
                #{quote(row['created_by_id'])}, #{quote(title)}, #{quote(description)}, 'open', 'high', #{quote(occurred_at)}, NOW(), NOW())
        RETURNING id
      SQL
      changes = { "source" => [ nil, "device_diagnostic" ], "title" => [ nil, title ], "integration_token" => row["token_name"] }
      execute <<~SQL.squish
        INSERT INTO audit_logs (user_id, action, auditable_type, auditable_id, changes_json, performed_at, created_at, site_id)
        VALUES (NULL, 'create', 'Trouble', #{quote(trouble_id)}, #{quote(changes.to_json)}, NOW(), NOW(), #{quote(site_id)})
      SQL
    end
  end

  def quote(value) = connection.quote(value)
end
