# AIの提案の記録。提案はあくまで下書きで、確定するのは人（トラブルになるのは、人が点検を保存したとき。対応記録になるのは、人が対応記録を保存したとき）。
# トラブル・対応記録がAIの下書きをもとに作られたかは、その作成の監査ログの ai_suggestion_id でたどる
class AiSuggestion < ApplicationRecord
  KINDS = %w[defect_draft similar_troubles response_draft].freeze
  # pending=呼び出し中（またはサーバが落ちて結果が残らなかったもの） / succeeded / failed
  STATUSES = %w[pending succeeded failed].freeze
  # 上限の判定と作成を直列にするためのアドバイザリロックのキー（他の用途と重ならない任意の値）
  LOCK_KEY = 84_210_001

  # 1日の上限に達したとき
  class LimitExceeded < StandardError
    attr_reader :scope

    # scope: :user（本人の上限）/ :total（全体の上限）
    def initialize(scope)
      @scope = scope
      super("AI suggestion daily limit exceeded (#{scope})")
    end
  end

  belongs_to :user
  belongs_to :equipment
  belongs_to :instrument, optional: true

  validates :kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }

  # 今日（日本時間）の呼び出し。失敗も数える
  scope :today, -> { where(created_at: Time.current.all_day) }

  # 提案の記録を作る。上限を超えていれば LimitExceeded。
  # 数えて作るまでを1つのロック（アドバイザリロック）で直列にし、同時に押されても上限を超えて作らない。
  # APIの呼び出しはこの外で行う（ロックを持ったまま待たない）
  def self.reserve!(user:, equipment:, instrument:, kind:, input:)
    transaction do
      connection.execute("SELECT pg_advisory_xact_lock(#{LOCK_KEY})")
      raise LimitExceeded, :user if today.where(user_id: user.id).count >= AiConfig.daily_limit_per_user
      raise LimitExceeded, :total if today.count >= AiConfig.daily_limit_total

      create!(user: user, equipment: equipment, instrument: instrument, kind: kind, input_json: input, model: AiConfig.model)
    end
  end

  # 本人の、今日の残り回数（全体の上限が先に尽きていればその分）
  def self.remaining_today_for(user)
    [ AiConfig.daily_limit_per_user - today.where(user_id: user.id).count,
      AiConfig.daily_limit_total - today.count ].min.clamp(0, AiConfig.daily_limit_per_user)
  end
end
