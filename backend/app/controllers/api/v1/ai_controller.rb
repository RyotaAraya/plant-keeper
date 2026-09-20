module Api
  module V1
    # AI支援。AIは下書き・候補の提案までで、ここでは何も保存しない（提案の記録と監査ログだけ）。
    # AIが使えないとき（キー未設定・上限・失敗・タイムアウト）も、その画面の入力は今まで通りできる
    class AiController < BaseController
      # 種類ごとの、画面に出す文言（何を取得できなかったか / AIがなくても続けられること）
      KIND_TEXT = {
        "defect_draft" => { noun: "下書き", fallback: "点検の入力はAIなしで続けられます" },
        "similar_troubles" => { noun: "類似トラブル", fallback: "トラブル一覧からは、AIなしで探せます" },
        "response_draft" => { noun: "下書き", fallback: "対応記録の入力はAIなしで続けられます" }
      }.freeze

      # GET /api/v1/ai/status — 画面が、AIのボタンを出すか・残り回数を出すかを決める
      def status
        authorize :ai, :status?
        enabled = AiConfig.enabled?
        render json: {
          data: {
            enabled: enabled,
            # どのAIか（fake=APIを呼ばないダミー / claude=本物）。無効なときは nil。E2Eが、本物のAPIを呼ばないために使う
            provider: (AiConfig.fake? ? "fake" : "claude" if enabled),
            daily_limit: AiConfig.daily_limit_per_user,
            remaining_today: enabled ? AiSuggestion.remaining_today_for(current_user) : 0,
            max_memo_length: AiConfig::MAX_MEMO_LENGTH
          }
        }
      end

      # POST /api/v1/ai/defect_drafts — 現場メモから、トラブル報告の下書きを返す
      def defect_draft
        authorize :ai, :defect_draft?
        return unless available?

        memo = read_memo("現場メモ")
        return unless memo

        equipment, instrument = read_target
        return unless equipment

        item_label = params[:item_label].to_s.strip.first(200)
        run_ai("defect_draft", equipment: equipment, instrument: instrument, input: { "memo" => memo, "item_label" => item_label }) do
          DefectDraftGenerator.new.call(equipment: equipment, instrument: instrument, item_label: item_label, memo: memo)
        end
      end

      # POST /api/v1/ai/similar_troubles — 現場メモに似た過去のトラブルを、対応の要約つきで返す
      def similar_troubles
        authorize :ai, :similar_troubles?
        return unless available?

        memo = read_memo("現場メモ")
        return unless memo

        equipment, instrument = read_target
        return unless equipment

        exclude_id = params[:exclude_trouble_id].presence&.to_i
        finder = SimilarTroubleFinder.new
        candidates = finder.candidates(equipment: equipment, instrument: instrument, exclude_trouble_id: exclude_id)
        # 比べる過去のトラブルがなければ、AIを呼ばない（回数にも数えない）
        return render json: { data: { "cases" => [], "candidates_count" => 0, "remaining_today" => AiSuggestion.remaining_today_for(current_user) } } if candidates.empty?

        input = { "memo" => memo, "exclude_trouble_id" => exclude_id, "candidate_ids" => candidates.map { |c| c.trouble.id } }
        run_ai("similar_troubles", equipment: equipment, instrument: instrument, input: input, extra: { "candidates_count" => candidates.size }) do
          finder.call(candidates: candidates, equipment: equipment, instrument: instrument, memo: memo)
        end
      end

      # POST /api/v1/ai/response_drafts — 対応メモから、対応記録の下書きを返す
      def response_draft
        authorize :ai, :response_draft?
        return unless available?

        memo = read_memo("対応メモ")
        return unless memo

        trouble = Trouble.includes(:equipment, :instrument).find_by(id: params[:trouble_id])
        return render_error("トラブルを指定してください", :unprocessable_entity) unless trouble

        run_ai("response_draft", equipment: trouble.equipment, instrument: trouble.instrument, input: { "memo" => memo, "trouble_id" => trouble.id }) do
          ResponseDraftGenerator.new.call(trouble: trouble, memo: memo)
        end
      end

      private

      # AIが使える環境か。使えないときは応答を返して false
      def available?
        return true if AiConfig.enabled?

        render_error("AI機能はこの環境では使えません", :service_unavailable)
        false
      end

      # 現場メモ・対応メモ。空・長すぎるときは応答を返して nil
      def read_memo(label)
        memo = params[:memo].to_s.strip
        return render_error("#{label}を入力してください", :unprocessable_entity) if memo.blank?
        return render_error("#{label}は#{AiConfig::MAX_MEMO_LENGTH}文字までです", :unprocessable_entity) if memo.length > AiConfig::MAX_MEMO_LENGTH

        memo
      end

      # 対象の設備と計器（任意）。不正なときは応答を返して nil
      def read_target
        equipment = Equipment.find_by(id: params[:equipment_id])
        return render_error("設備を選んでください", :unprocessable_entity) unless equipment

        instrument = nil
        if params[:instrument_id].present?
          instrument = equipment.instruments.find_by(id: params[:instrument_id])
          return render_error("指定した計器が設備に属していません", :unprocessable_entity) unless instrument
        end
        [ equipment, instrument ]
      end

      # 上限の判定 → AIの呼び出し → 成功の記録、までの共通の流れ。ブロックはAIを呼んで Result を返す。
      # 種類ごとに違うのは、AIに渡す入力と、返す内容だけ
      def run_ai(kind, equipment:, instrument:, input:, extra: {}, &generate)
        suggestion = reserve_suggestion(kind, equipment, instrument, input)
        return unless suggestion

        result = request_ai(suggestion, &generate)
        return unless result

        # 成功の記録は、状態と監査ログを1つにする（監査ログが書けなかったときは、成功の記録も戻して500にする。
        # AIの失敗ではないので、失敗として記録しない。押し直せるよう、回数には数えたまま）
        AiSuggestion.transaction do
          suggestion.update!(status: "succeeded", output_json: result.draft, input_tokens: result.input_tokens, output_tokens: result.output_tokens)
          record_audit_log("create", suggestion, changes: audit_changes_for(suggestion))
        end
        render json: { data: result.draft.merge(extra).merge("suggestion_id" => suggestion.id, "remaining_today" => AiSuggestion.remaining_today_for(current_user)) }
      end

      # 上限の判定と提案の記録の作成。上限に達したときは応答を返して nil
      def reserve_suggestion(kind, equipment, instrument, input)
        AiSuggestion.reserve!(user: current_user, equipment: equipment, instrument: instrument, kind: kind, input: input)
      rescue AiSuggestion::LimitExceeded => e
        fallback = KIND_TEXT.fetch(kind)[:fallback]
        message = if e.scope == :user
          "今日のAI利用回数の上限（#{AiConfig.daily_limit_per_user}回）に達しました。#{fallback}"
        else
          "デモ全体の今日のAI利用回数の上限に達しました。#{fallback}"
        end
        render_error(message, :too_many_requests)
      end

      # AIを呼ぶ。APIの障害・タイムアウト・使えない応答のどれでも、画面の入力を止めず、失敗として記録する
      # （失敗も1回に数える）。失敗の応答を返したときは nil
      def request_ai(suggestion)
        yield
      rescue StandardError => e
        suggestion.update!(status: "failed", error_class: e.class.name)
        Rails.logger.error("[AI] #{suggestion.kind} failed: #{e.class}: #{e.message}")
        timeout = e.is_a?(::Anthropic::Errors::APITimeoutError)
        text = KIND_TEXT.fetch(suggestion.kind)
        render_error("AIから#{text[:noun]}を取得できませんでした（#{timeout ? "時間がかかりすぎました" : "しばらくしてからもう一度お試しください"}）。#{text[:fallback]}",
                     timeout ? :gateway_timeout : :bad_gateway)
      end

      # 監査ログの画面は値を文字列として並べるため、入出力（JSON）は主な項目を文字列に展開する（全文は ai_suggestions に残る）
      def audit_changes_for(suggestion)
        input = suggestion.input_json
        output = suggestion.output_json
        common = { "kind" => suggestion.kind, "model" => suggestion.model, "equipment_id" => suggestion.equipment_id, "instrument_id" => suggestion.instrument_id }
        case suggestion.kind
        when "defect_draft"
          common.merge("memo" => input["memo"], "title" => output["title"], "priority" => output["priority"])
        when "similar_troubles"
          common.merge("memo" => input["memo"], "trouble_ids" => output["cases"].map { |c| c["trouble_id"] }.join(", "))
        when "response_draft"
          common.merge("trouble_id" => input["trouble_id"], "memo" => input["memo"], "response_type" => output["response_type"])
        end
      end

      # 応答を返して nil（呼び出し側が、そのまま nil を返して中断できるように）
      def render_error(message, status)
        render json: { errors: [ message ] }, status: status
        nil
      end
    end
  end
end
