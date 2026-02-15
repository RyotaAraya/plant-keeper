module Api
  module V1
    class MaterialsController < BaseController
      before_action :set_material, only: [ :show, :update ]

      # GET /api/v1/materials
      def index
        materials = Material.includes(:manufacturer).all
        materials = materials.where(manufacturer_id: params[:manufacturer_id]) if params[:manufacturer_id].present?
        materials = materials.where(category: params[:category]) if params[:category].present?
        materials = materials.where(availability: params[:availability]) if params[:availability].present?

        if params[:q].present?
          q = "%#{params[:q]}%"
          normalized = params[:q].gsub(/[-\s]/, "")
          materials = materials.where(
            "name ILIKE ? OR part_number ILIKE ? OR normalized_part_number ILIKE ?",
            q, q, "%#{normalized}%"
          )
        end

        materials = materials.order(:name)
        total_count = materials.count

        page = (params[:page] || 1).to_i
        per_page = (params[:per_page] || 25).to_i
        materials = materials.limit(per_page).offset((page - 1) * per_page)

        render json: {
          data: materials.as_json(include: { manufacturer: { only: [ :id, :name ] } }),
          meta: { total_count: total_count, page: page, per_page: per_page }
        }
      end

      # GET /api/v1/materials/:id
      def show
        stocks_summary = @material.stocks.group(:warehouse_id).sum(:quantity)
        warehouses = Warehouse.where(id: stocks_summary.keys).index_by(&:id)

        render json: {
          data: @material.as_json(
            include: { manufacturer: { only: [ :id, :name ] } }
          ).merge(
            stock_summary: stocks_summary.map { |wid, qty| { warehouse: warehouses[wid]&.name, quantity: qty } },
            total_stock: stocks_summary.values.sum,
            recent_orders: @material.orders.order(ordered_on: :desc).limit(5).as_json(
              include: { user: { only: [ :id, :name ] } }
            )
          )
        }
      end

      # POST /api/v1/materials
      def create
        material = Material.new(material_params)
        if material.save
          render json: { data: material.as_json }, status: :created
        else
          render json: { errors: material.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/materials/:id
      def update
        if @material.update(material_params)
          render json: { data: @material.as_json(include: { manufacturer: { only: [ :id, :name ] } }) }
        else
          render json: { errors: @material.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def set_material
        @material = Material.includes(:manufacturer, :stocks, orders: :user).find(params[:id])
      end

      def material_params
        params.require(:material).permit(
          :manufacturer_id, :part_number, :name, :description,
          :former_part_numbers, :availability, :category, :rating,
          :lead_time_days, :is_hazardous, :hazard_note,
          :reorder_method, :reorder_point, :reorder_quantity
        )
      end
    end
  end
end
