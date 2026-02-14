module Api
  module V1
    class TroubleResponsesController < BaseController
      # POST /api/v1/trouble_responses
      def create
        response = TroubleResponse.new(response_params)
        response.user = current_user

        if response.save
          render json: {
            data: response.as_json(include: { user: { only: [:id, :name] } })
          }, status: :created
        else
          render json: { errors: response.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/trouble_responses/:id
      def update
        response = TroubleResponse.find(params[:id])

        if response.update(response_params)
          render json: {
            data: response.as_json(include: { user: { only: [:id, :name] } })
          }
        else
          render json: { errors: response.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def response_params
        params.require(:trouble_response).permit(
          :trouble_id, :response_type, :description, :used_materials, :responded_at
        )
      end
    end
  end
end
