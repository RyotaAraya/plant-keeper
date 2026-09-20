# 監査ログを拠点で絞れるようにする。拠点は「変更されたデータの拠点」（操作した人の所属ではない）。
# 資材・メーカー・流体などの全社共通マスタは拠点を持たないため NULL（拠点なし）のまま。
# 既存の記録の拠点は、次の移行（BackfillAuditLogSites）で埋める
class AddSiteToAuditLogs < ActiveRecord::Migration[8.0]
  def change
    add_reference :audit_logs, :site, foreign_key: true, index: true, null: true
  end
end
