# AI支援のテストで共通の部品。AIのAPIは呼ばず、クライアントを差し替えて検証する
module AiTestSupport
  AI_ENV_KEYS = %w[ANTHROPIC_API_KEY AI_PROVIDER AI_ENABLED AI_DAILY_LIMIT_PER_USER AI_DAILY_LIMIT_TOTAL].freeze

  # 呼ばれた内容を記録し、決めた応答（または例外）を返す
  class StubClient
    attr_reader :calls

    def initialize(json: nil, error: nil)
      @json = json
      @error = error
      @calls = []
    end

    def complete(system:, user:, schema:)
      @calls << { system: system, user: user, schema: schema }
      raise @error if @error

      AiClient::Response.new(json: @json, input_tokens: 120, output_tokens: 80)
    end
  end

  # AIが使える状態（キーあり・上限は既定）にする。teardown_ai_env で元に戻す
  def setup_ai_env
    @saved_ai_env = ENV.to_h.slice(*AI_ENV_KEYS)
    AI_ENV_KEYS.each { |k| ENV.delete(k) }
    ENV["ANTHROPIC_API_KEY"] = "test-key"
  end

  def teardown_ai_env
    AiClient.override = nil
    AI_ENV_KEYS.each { |k| ENV.delete(k) }
    @saved_ai_env.each { |k, v| ENV[k] = v }
  end

  def use_client(client)
    @client = client
    AiClient.override = client
  end
end
