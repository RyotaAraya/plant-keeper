# AIのAPIを呼ぶ層。呼び出し側（DefectDraftGenerator）は、モデルやAPIの違いを知らずに complete だけを使う。
# 環境で切り替える: 通常は Claude（Anthropic API）、AI_PROVIDER=fake なら Fake（APIを呼ばない）
module AiClient
  # json: スキーマに従って返ってきたJSON（パース済み）
  Response = Struct.new(:json, :input_tokens, :output_tokens, keyword_init: true)

  # 応答が使えない（拒否・途中で切れた・JSONでない）
  class UnusableResponse < StandardError; end

  class << self
    # テストで差し替える（既定は環境設定に従う）
    attr_writer :override

    def build
      return @override if @override

      AiConfig.fake? ? Fake.new : Claude.new
    end
  end
end
