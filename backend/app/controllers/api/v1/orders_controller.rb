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

        page, per_page = pagination_params
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

        # 受領済・キャンセルでの新規作成は不可（受領は入庫を伴うため、発注済から受領の操作で行う）
        unless %w[draft ordered].include?(order.status)
          return render json: { errors: [ "新規登録できるのは下書きまたは発注済のみです" ] }, status: :unprocessable_entity
        end

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

        ActiveRecord::Base.transaction do
          # 同時に受領されても、二重に入庫しないよう、発注の行をロックして最新の状態から更新する
          @order.lock!
          @order.update!(order_params)
          record_audit_log("update", @order)
          receive_into_stock! if @order.saved_change_to_status? && @order.received?
        end

        render json: {
          data: @order.as_json(
            include: {
              material: { only: [ :id, :name, :part_number ] },
              user: { only: [ :id, :name ] },
              warehouse: { only: [ :id, :name ] }
            }
          )
        }
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
      end

      private

      # 受領した資材を在庫に入庫する。同じロット（資材・倉庫・購入日=受領日が同じ）があれば数量を足し、入庫を台帳に残す
      def receive_into_stock!
        lot = Stock.lock.find_or_initialize_by(
          material_id: @order.material_id, warehouse_id: @order.warehouse_id,
          purchased_on: @order.received_on, status: "available", serial_number: nil
        )
        lot.quantity += @order.quantity
        lot.save!

        incoming = lot.stock_transactions.create!(
          user: current_user, transaction_type: "incoming", quantity: @order.quantity,
          reason: "発注の受領（発注ID: #{@order.id}）", transacted_at: Time.current
        )
        record_audit_log("create", incoming)
      end

      def set_order
        @order = Order.includes(:material, :user).find(params[:id])
      end

      def order_params
        params.require(:order).permit(
          :material_id, :quantity, :unit_price,
          :supplier_name, :supplier_link, :status, :warehouse_id,
          :ordered_on, :received_on, :notes
        )
      end
    end
  end
end
