# 既存の定期整備を、1件ずつ「単体の親」にする: 拠点は設備から、対象設備は元の設備1件、予定期間の開始日は scheduled_date、
# 実績の終了日は completed_date。状態・担当者はそのまま。すでに移行した行（拠点が入っている行）には触れないため、何度実行しても同じ結果になる。
# そのあと、拠点と予定開始日を必須にする。モデルのコードには依存しない（生SQL）
class BackfillScheduledMaintenanceParents < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL.squish
      UPDATE scheduled_maintenances sm
      SET site_id = e.site_id, planned_start_on = sm.scheduled_date, actual_end_on = sm.completed_date
      FROM equipments e
      WHERE e.id = sm.equipment_id AND sm.site_id IS NULL
    SQL
    execute <<~SQL.squish
      INSERT INTO scheduled_maintenance_equipments (scheduled_maintenance_id, equipment_id, created_at, updated_at)
      SELECT sm.id, sm.equipment_id, NOW(), NOW() FROM scheduled_maintenances sm
      WHERE sm.equipment_id IS NOT NULL
        AND NOT EXISTS (SELECT 1 FROM scheduled_maintenance_equipments x WHERE x.scheduled_maintenance_id = sm.id AND x.equipment_id = sm.equipment_id)
    SQL
    change_column_null :scheduled_maintenances, :site_id, false
    change_column_null :scheduled_maintenances, :planned_start_on, false
  end

  def down
    # 移行した値は、利用者の編集と区別できないため、ここでは戻さない
  end
end
