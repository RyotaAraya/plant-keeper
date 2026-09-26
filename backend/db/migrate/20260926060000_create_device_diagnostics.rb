# 機器の自己診断（NAMUR NE 107）の受け口: 連携用のトークン、計器ごとの診断の履歴、計器のいまの診断の状態
class CreateDeviceDiagnostics < ActiveRecord::Migration[8.0]
  STATUSES = %w[good failure function_check out_of_specification maintenance_required].freeze

  def change
    # 機器管理システム（AMS・PRM など）が診断を送るときのトークン。拠点ごとに発行し、平文は保存しない（SHA-256）
    create_table :integration_tokens do |t|
      t.string :name, null: false
      t.references :site, null: false, foreign_key: true
      t.string :token_digest, null: false
      t.string :token_hint, null: false # 画面で見分けるための末尾4文字
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.datetime :last_used_at
      t.datetime :revoked_at
      t.references :revoked_by, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :integration_tokens, :token_digest, unique: true

    # 診断の状態が変わったときの履歴（同じ状態を受け取り続けても行は増やさない）
    create_table :instrument_diagnostics do |t|
      t.references :instrument, null: false, foreign_key: true
      t.string :status, null: false
      t.string :code
      t.text :message
      t.datetime :occurred_at, null: false
      t.references :integration_token, foreign_key: true
      t.timestamps
    end
    add_index :instrument_diagnostics, [ :instrument_id, :occurred_at ]
    add_check_constraint :instrument_diagnostics, "status IN (#{STATUSES.map { |s| "'#{s}'" }.join(', ')})", name: "instrument_diagnostics_status"

    # いまの状態（一覧で絞り込み・表示するため、計器に持つ）。未受信は NULL
    add_column :instruments, :diagnostic_status, :string
    add_column :instruments, :diagnostic_since, :datetime # いまの状態になった日時（機器が出した日時）
    add_column :instruments, :diagnostic_received_at, :datetime # 最後に受け取った日時
    add_index :instruments, :diagnostic_status
  end
end
