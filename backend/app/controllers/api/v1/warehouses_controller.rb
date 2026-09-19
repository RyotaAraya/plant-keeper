module Api
  module V1
    class WarehousesController < BaseController
      # GET /api/v1/warehouses
      def index
        authorize Warehouse
        warehouses = Warehouse.includes(:site).order(:name).all
        if (site_ids = id_list_param(:site_ids, :site_id))
          warehouses = warehouses.where(site_id: site_ids)
        end
        render json: {
          data: warehouses.as_json(include: { site: { only: [ :id, :name ] } })
        }
      end

      # POST /api/v1/warehouses
      def create
        warehouse = Warehouse.new(warehouse_params)
        authorize warehouse
        if warehouse.save
          record_audit_log("create", warehouse)
          render json: { data: warehouse.as_json }, status: :created
        else
          render json: { errors: warehouse.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/warehouses/:id
      def update
        warehouse = Warehouse.find(params[:id])
        authorize warehouse
        if warehouse.update(warehouse_params)
          record_audit_log("update", warehouse)
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
