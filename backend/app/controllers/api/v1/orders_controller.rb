module Api
  module V1
    class OrdersController < BaseController
      before_action :set_order, only: [ :show, :update ]

      # GET /api/v1/orders
      def index
        authorize Order
        orders = Order.includes(:material, :user).all
        orders = orders.where(material_id: params[:material_id]) if params[:material_id].present?
        orders = orders.where(status: params[:status]) if params[:status].present?

        orders = orders.order(ordered_on: :desc)
        total_count = orders.count

        page = (params[:page] || 1).to_i
        per_page = (params[:per_page] || 25).to_i
        orders = orders.limit(per_page).offset((page - 1) * per_page)

        render json: {
          data: orders.as_json(
            include: {
              material: { only: [ :id, :name, :part_number ] },
              user: { only: [ :id, :name ] }
            }
          ),
          meta: { total_count: total_count, page: page, per_page: per_page }
        }
      end

      # GET /api/v1/orders/:id
      def show
        authorize @order
        render json: {
          data: @order.as_json(
            include: {
              material: { only: [ :id, :name, :part_number ] },
              user: { only: [ :id, :name ] }
            }
          )
        }
      end

      # POST /api/v1/orders
      def create
        order = Order.new(order_params)
        authorize order
        order.user = current_user

        if order.save
          record_audit_log("create", order)
          render json: { data: order.as_json }, status: :created
        else
          render json: { errors: order.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/orders/:id
      def update
        authorize @order
        if @order.update(order_params)
          record_audit_log("update", @order)
          render json: {
            data: @order.as_json(
              include: {
                material: { only: [ :id, :name, :part_number ] },
                user: { only: [ :id, :name ] }
              }
            )
          }
        else
          render json: { errors: @order.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def set_order
        @order = Order.includes(:material, :user).find(params[:id])
      end

      def order_params
        params.require(:order).permit(
          :material_id, :quantity, :unit_price,
          :supplier_name, :supplier_link, :status,
          :ordered_on, :received_on, :notes
        )
      end
    end
  end
end
