class MergeSubmittedInspectionsIntoApproved < ActiveRecord::Migration[8.0]
  def up
    # 提出済は、承認を頼まれずに確定した記録として承認済みに移す（承認待ちに移すと、過去の記録がすべて承認者の承認待ちに並ぶため）。
    # 状態だけを移行する。点検日・計画の期限・作業・監査ログは変更しない。
    execute "UPDATE inspections SET status = 'approved' WHERE status = 'submitted'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "統合前の提出済と承認済みを区別できないため戻せません"
  end
end
