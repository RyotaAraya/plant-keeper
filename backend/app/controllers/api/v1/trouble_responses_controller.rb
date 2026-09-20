module Api
  module V1
    class TroubleResponsesController < BaseController
      # POST /api/v1/trouble_responses
      def create
        response = TroubleResponse.new(response_params)
        authorize response
        response.user = current_user

        if response.save
          # AIの下書きをもとにしたときは、その提案のIDを残す（AIの案と、人が確定した内容を突き合わせられるように）
          changes = response.saved_changes.except("updated_at", "created_at")
          suggestion_id = ai_suggestion_id_for(response, params.dig(:trouble_response, :ai_suggestion_id))
          changes = changes.merge("ai_suggestion_id" => suggestion_id) if suggestion_id
          record_audit_log("create", response, changes: changes)
          render json: {
            data: response.as_json(include: { user: { only: [ :id, :name ] } })
          }, status: :created
        else
          render json: { errors: response.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/trouble_responses/:id
      def update
        response = TroubleResponse.find(params[:id])
        authorize response

        if response.update(response_params)
          record_audit_log("update", response)
          render json: {
            data: response.as_json(include: { user: { only: [ :id, :name ] } })
          }
        else
          render json: { errors: response.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      # 画面から送られた提案のIDのうち、本人が今回のトラブルについて作った成功済みの対応記録の下書きだけを認める。
      # 一致しないものは黙って無視する（別のトラブルの画面で作った下書きが送られても、記録の保存を止めない）
      def ai_suggestion_id_for(response, id)
        return if id.blank?

        suggestion = AiSuggestion.find_by(id: id, user_id: current_user.id, kind: "response_draft", status: "succeeded")
        suggestion.id if suggestion && suggestion.input_json["trouble_id"] == response.trouble_id
      end

      def response_params
        params.require(:trouble_response).permit(
          :trouble_id, :response_type, :description, :used_materials, :responded_at
        )
      end
    end
  end
end
