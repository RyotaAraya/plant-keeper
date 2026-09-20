module Api
  module V1
    class RegulationsController < BaseController
      # GET /api/v1/regulations
      def index
        authorize Regulation
        regulations = Regulation.includes(:regulation_inspections).order(:id)
        regulations = regulations.where(target: params[:target]) if Regulation.targets.key?(params[:target])

        render json: {
          data: regulations.as_json(
            include: { regulation_inspections: { only: [ :id, :name, :interval_days, :basis, :note ] } }
          )
        }
      end
    end
  end
end
