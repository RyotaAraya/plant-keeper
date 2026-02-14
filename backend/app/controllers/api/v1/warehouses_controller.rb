module Api
  module V1
    class WarehousesController < BaseController
      # GET /api/v1/warehouses
      def index
        warehouses = Warehouse.includes(:site).order(:name).all
        warehouses = warehouses.where(site_id: params[:site_id]) if params[:site_id].present?
        render json: {
          data: warehouses.as_json(include: { site: { only: [:id, :name] } })
        }
      end

      # POST /api/v1/warehouses
      def create
        warehouse = Warehouse.new(warehouse_params)
        if warehouse.save
          render json: { data: warehouse.as_json }, status: :created
        else
          render json: { errors: warehouse.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/warehouses/:id
      def update
        warehouse = Warehouse.find(params[:id])
        if warehouse.update(warehouse_params)
          render json: { data: warehouse.as_json }
        else
          render json: { errors: warehouse.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def warehouse_params
        params.require(:warehouse).permit(:site_id, :name)
      end
    end
  end
end
