class MergeSubmittedInspectionsIntoApprovalRequested < ActiveRecord::Migration[8.0]
  def up
    # 状態だけを移行する。点検日・計画の期限・作業・監査ログは変更しない。
    execute "UPDATE inspections SET status = 'approval_requested' WHERE status = 'submitted'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "統合前の提出済と承認待ちを区別できないため戻せません"
  end
end
