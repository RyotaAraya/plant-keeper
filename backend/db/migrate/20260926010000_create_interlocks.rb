# インターロック（安全計装）の台帳と、その一時的なバイパス（申請・承認・実施・復帰・復帰確認）
class CreateInterlocks < ActiveRecord::Migration[8.0]
  def change
    create_table :interlocks do |t|
      t.references :equipment, null: false, foreign_key: true
      t.string :tag_number, null: false
      t.string :name, null: false
      # トリップしたときに何が起きるか（例: バーナー燃料ガス遮断弁 XV-701 を閉じ、ボイラーを停止する）
      t.text :trip_action
      t.text :notes
      t.boolean :is_active, null: false, default: true
      t.timestamps
    end
    add_index :interlocks, [ :equipment_id, :tag_number ], unique: true

    create_table :interlock_instruments do |t|
      t.references :interlock, null: false, foreign_key: true
      t.references :instrument, null: false, foreign_key: true
      t.timestamps
    end
    add_index :interlock_instruments, [ :interlock_id, :instrument_id ], unique: true

    create_table :interlock_bypasses do |t|
      t.references :interlock, null: false, foreign_key: true
      t.string :request_number, null: false
      t.string :status, null: false, default: "requested"
      t.text :reason, null: false
      # バイパス中の代替措置（インターロックの代わりに、どう監視・保護するか）
      t.text :compensatory_measure, null: false
      t.datetime :planned_restore_at, null: false
      t.references :requested_by, null: false, foreign_key: { to_table: :users }
      t.datetime :requested_at, null: false
      t.references :approved_by, foreign_key: { to_table: :users }
      t.datetime :approved_at
      t.references :bypassed_by, foreign_key: { to_table: :users }
      t.datetime :bypassed_at
      t.references :restored_by, foreign_key: { to_table: :users }
      t.datetime :restored_at
      t.references :confirmed_by, foreign_key: { to_table: :users }
      t.datetime :confirmed_at
      # 却下・取消（誰が・いつ・なぜ）
      t.references :closed_by, foreign_key: { to_table: :users }
      t.datetime :closed_at
      t.text :closed_reason
      t.timestamps
    end
    add_index :interlock_bypasses, :request_number, unique: true
    add_index :interlock_bypasses, :status
    # 1つのインターロックに、終わっていないバイパスは1件だけ
    add_index :interlock_bypasses, :interlock_id, unique: true, name: "index_interlock_bypasses_one_open",
                                                  where: "status IN ('requested', 'approved', 'bypassed', 'restored')"
  end
end
