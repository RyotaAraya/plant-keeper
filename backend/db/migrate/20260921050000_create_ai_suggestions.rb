# AIの提案の記録（不具合報告の下書きなど）。呼び出しごとに1行で、誰が・いつ・どの設備で・何を入力し・何が返ったかを残す。
# 1日の回数の上限（ユーザ別・全体）も、この表の行数で数える。失敗した呼び出しも数える（費用が発生しうるため）
class CreateAiSuggestions < ActiveRecord::Migration[8.0]
  def change
    create_table :ai_suggestions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :equipment, null: false, foreign_key: true
      t.references :instrument, foreign_key: true
      t.string :kind, null: false
      t.string :status, null: false, default: "pending"
      t.string :model
      t.jsonb :input_json, null: false, default: {}
      t.jsonb :output_json
      t.integer :input_tokens
      t.integer :output_tokens
      t.string :error_class
      t.timestamps
    end
    add_index :ai_suggestions, :created_at
    add_index :ai_suggestions, [ :user_id, :created_at ]
  end
end
