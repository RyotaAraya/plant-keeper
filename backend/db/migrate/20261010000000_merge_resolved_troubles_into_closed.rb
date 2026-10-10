class MergeResolvedTroublesIntoClosed < ActiveRecord::Migration[8.0]
  def up
    # 完了済みの案件として移行する。既存の日時と監査ログは保持する。
    execute <<~SQL
      UPDATE troubles
      SET status = 'closed', resolved_at = COALESCE(resolved_at, updated_at)
      WHERE status = 'resolved'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "統合前の解決済と完了を区別できないため戻せません"
  end
end
