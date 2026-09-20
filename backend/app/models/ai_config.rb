# AI機能の設定（環境変数）。AIは補助で、使えない環境（キー未設定・無効化）でもアプリの他の機能は変わらない
#
# - ANTHROPIC_API_KEY: 設定されていればAIを使える（未設定の環境ではボタン自体を出さない）
# - AI_PROVIDER=fake: APIを呼ばず、決まった形式の下書きを返す（E2E・キーなしの動作確認用）
# - AI_ENABLED=false: キーがあっても止める
# - AI_MODEL: 使うモデル（既定は小型のHaiku 4.5。構造化・要約には足りる）
# - AI_DAILY_LIMIT_PER_USER / AI_DAILY_LIMIT_TOTAL: 1日（日本時間）の呼び出し回数の上限
class AiConfig
  DEFAULT_MODEL = "claude-haiku-4-5"
  DEFAULT_DAILY_LIMIT_PER_USER = 20
  DEFAULT_DAILY_LIMIT_TOTAL = 200
  # 現場メモの最大文字数
  MAX_MEMO_LENGTH = 1000
  # APIの応答を待つ上限（秒）。超えたら諦めて、AIなしで入力を続けてもらう
  TIMEOUT_SECONDS = 15

  class << self
    def fake? = ENV["AI_PROVIDER"] == "fake"

    def enabled?
      return false if ENV["AI_ENABLED"] == "false"

      fake? || ENV["ANTHROPIC_API_KEY"].present?
    end

    def model = ENV["AI_MODEL"].presence || DEFAULT_MODEL

    def daily_limit_per_user = positive_int("AI_DAILY_LIMIT_PER_USER", DEFAULT_DAILY_LIMIT_PER_USER)

    def daily_limit_total = positive_int("AI_DAILY_LIMIT_TOTAL", DEFAULT_DAILY_LIMIT_TOTAL)

    private

    # 0以下・数値でない値は既定に戻す（誤設定で上限が無効になったり、全員が使えなくなったりしないように）
    def positive_int(key, default)
      value = ENV[key].to_i
      value.positive? ? value : default
    end
  end
end
