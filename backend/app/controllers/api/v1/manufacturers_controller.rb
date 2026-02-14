module Api
  module V1
    class ManufacturersController < BaseController
      # GET /api/v1/manufacturers
      def index
        manufacturers = Manufacturer.order(:name).all
        render json: { data: manufacturers.as_json }
      end

      # POST /api/v1/manufacturers
      def create
        manufacturer = Manufacturer.new(manufacturer_params)
        if manufacturer.save
          render json: { data: manufacturer.as_json }, status: :created
        else
          render json: { errors: manufacturer.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/manufacturers/:id
      def update
        manufacturer = Manufacturer.find(params[:id])
        if manufacturer.update(manufacturer_params)
          render json: { data: manufacturer.as_json }
        else
          render json: { errors: manufacturer.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def manufacturer_params
        params.require(:manufacturer).permit(:name, :former_names, :notes)
      end
    end
  end
end
