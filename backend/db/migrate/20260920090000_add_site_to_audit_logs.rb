# 監査ログを拠点で絞れるようにする。拠点は「変更されたデータの拠点」（操作した人の所属ではない）。
# 資材・メーカー・流体などの全社共通マスタは拠点を持たないため NULL（拠点なし）のまま
class AddSiteToAuditLogs < ActiveRecord::Migration[8.0]
  def up
    add_reference :audit_logs, :site, foreign_key: true, index: true, null: true

    AuditLog.reset_column_information
    AuditLog.find_each do |log|
      site_id = AuditLog.site_id_for(log.auditable)
      log.update_columns(site_id: site_id) if site_id
    end
  end

  def down
    remove_reference :audit_logs, :site, foreign_key: true, index: true
  end
end
