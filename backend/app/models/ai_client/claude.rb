# Claude API（Anthropic）で、JSONスキーマに従う出力を得る。
# 出力の形はスキーマ（output_config.format）で固定する。スキーマでは文字数・個数の制約を表せないため、それは呼び出し側で検証する
module AiClient
  class Claude
    # 下書きは短いJSONで、これを超えるのは異常（途中で切れたら使えないものとして扱う）
    MAX_TOKENS = 1024

    def initialize(model: AiConfig.model)
      @model = model
      # 待つのは AiConfig::TIMEOUT_SECONDS まで。再試行はしない（再試行すると待ち時間がその分延びるため。押し直すのは人）
      @client = ::Anthropic::Client.new(api_key: ENV.fetch("ANTHROPIC_API_KEY"), timeout: AiConfig::TIMEOUT_SECONDS, max_retries: 0)
    end

    def complete(system:, user:, schema:)
      message = @client.messages.create(
        model: @model.to_sym,
        max_tokens: MAX_TOKENS,
        system_: system,
        messages: [ { role: "user", content: user } ],
        output_config: { format_: { type: :json_schema, schema: schema } }
      )
      raise UnusableResponse, "refused" if message.stop_reason == :refusal
      raise UnusableResponse, "truncated" if message.stop_reason == :max_tokens

      text = message.content.find { |block| block.type == :text }&.text
      raise UnusableResponse, "no text" if text.blank?

      Response.new(json: JSON.parse(text), input_tokens: message.usage.input_tokens, output_tokens: message.usage.output_tokens)
    rescue JSON::ParserError
      raise UnusableResponse, "not json"
    end
  end
end
