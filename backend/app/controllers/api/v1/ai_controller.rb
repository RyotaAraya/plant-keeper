module Api
  module V1
    # AI支援。AIは下書きの提案までで、ここでは何も保存しない（提案の記録と監査ログだけ）。
    # AIが使えないとき（キー未設定・上限・失敗・タイムアウト）も、点検の入力と提出は今まで通りできる
    class AiController < BaseController
      # GET /api/v1/ai/status — 画面が、AIのボタンを出すか・残り回数を出すかを決める
      def status
        authorize :ai, :status?
        enabled = AiConfig.enabled?
        render json: {
          data: {
            enabled: enabled,
            daily_limit: AiConfig.daily_limit_per_user,
            remaining_today: enabled ? AiSuggestion.remaining_today_for(current_user) : 0,
            max_memo_length: AiConfig::MAX_MEMO_LENGTH
          }
        }
      end

      # POST /api/v1/ai/defect_drafts — 現場メモから、トラブル報告の下書きを返す
      def defect_draft
        authorize :ai, :defect_draft?
        return render_error("AI機能はこの環境では使えません", :service_unavailable) unless AiConfig.enabled?

        memo = params[:memo].to_s.strip
        return render_error("現場メモを入力してください", :unprocessable_entity) if memo.blank?
        return render_error("現場メモは#{AiConfig::MAX_MEMO_LENGTH}文字までです", :unprocessable_entity) if memo.length > AiConfig::MAX_MEMO_LENGTH

        equipment = Equipment.find_by(id: params[:equipment_id])
        return render_error("設備を選んでください", :unprocessable_entity) unless equipment

        instrument = nil
        if params[:instrument_id].present?
          instrument = equipment.instruments.find_by(id: params[:instrument_id])
          return render_error("指定した計器が設備に属していません", :unprocessable_entity) unless instrument
        end
        item_label = params[:item_label].to_s.strip.first(200)

        suggestion = reserve_suggestion(equipment, instrument, item_label, memo)
        return unless suggestion

        generate_draft(suggestion, equipment, instrument, item_label, memo)
      end

      private

      # 上限の判定と提案の記録の作成。上限に達したときは応答を返して nil
      def reserve_suggestion(equipment, instrument, item_label, memo)
        AiSuggestion.reserve!(
          user: current_user, equipment: equipment, instrument: instrument, kind: "defect_draft",
          input: { "memo" => memo, "item_label" => item_label }
        )
      rescue AiSuggestion::LimitExceeded => e
        message = if e.scope == :user
          "今日のAI利用回数の上限（#{AiConfig.daily_limit_per_user}回）に達しました。点検の入力はAIなしで続けられます"
        else
          "デモ全体の今日のAI利用回数の上限に達しました。点検の入力はAIなしで続けられます"
        end
        render_error(message, :too_many_requests)
        nil
      end

      def generate_draft(suggestion, equipment, instrument, item_label, memo)
        result = DefectDraftGenerator.new.call(equipment: equipment, instrument: instrument, item_label: item_label, memo: memo)

        suggestion.update!(status: "succeeded", output_json: result.draft, input_tokens: result.input_tokens, output_tokens: result.output_tokens)
        record_audit_log("create", suggestion, changes: audit_changes_for(suggestion))
        render json: { data: result.draft.merge("suggestion_id" => suggestion.id, "remaining_today" => AiSuggestion.remaining_today_for(current_user)) }
      rescue StandardError => e
        # APIの障害・タイムアウト・使えない応答のどれでも、点検の入力を止めない（失敗も1回に数える）
        suggestion.update!(status: "failed", error_class: e.class.name)
        Rails.logger.error("[AI] defect_draft failed: #{e.class}: #{e.message}")
        timeout = e.is_a?(::Anthropic::Errors::APITimeoutError)
        render_error("AIから下書きを取得できませんでした（#{timeout ? "時間がかかりすぎました" : "しばらくしてからもう一度お試しください"}）。点検の入力はAIなしで続けられます",
                     timeout ? :gateway_timeout : :bad_gateway)
      end

      # 監査ログの画面は値を文字列として並べるため、入出力（JSON）は主な項目を文字列に展開する（全文は ai_suggestions に残る）
      def audit_changes_for(suggestion)
        {
          "kind" => suggestion.kind,
          "model" => suggestion.model,
          "equipment_id" => suggestion.equipment_id,
          "instrument_id" => suggestion.instrument_id,
          "memo" => suggestion.input_json["memo"],
          "title" => suggestion.output_json["title"],
          "priority" => suggestion.output_json["priority"]
        }
      end

      def render_error(message, status)
        render json: { errors: [ message ] }, status: status
      end
    end
  end
end
