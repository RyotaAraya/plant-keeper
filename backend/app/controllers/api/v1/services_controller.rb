module Api
  module V1
    class ServicesController < BaseController
      def index
        render json: { data: Service.order(:name).as_json }
      end

      def create
        service = Service.new(service_params)
        authorize service
        if service.save
          render json: { data: service.as_json }, status: :created
        else
          render json: { errors: service.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        service = Service.find(params[:id])
        authorize service
        if service.update(service_params)
          render json: { data: service.as_json }
        else
          render json: { errors: service.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def service_params
        params.require(:service).permit(:name, :temperature, :pressure, :hazard_level, :hazard_description)
      end
    end
  end
end
