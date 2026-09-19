module Api
  module V1
    class StocksController < BaseController
      before_action :set_stock, only: [ :show, :update ]

      # GET /api/v1/stocks
      def index
        authorize Stock
        stocks = Stock.includes(:material, :warehouse).all
        stocks = stocks.where(material_id: params[:material_id]) if params[:material_id].present?
        stocks = stocks.where(warehouse_id: params[:warehouse_id]) if params[:warehouse_id].present?
        stocks = stocks.where(status: params[:status]) if params[:status].present?

        stocks = stocks.order(purchased_on: :asc)
        total_count = stocks.count

        page, per_page = pagination_params
        stocks = stocks.limit(per_page).offset((page - 1) * per_page)

        render json: {
          data: stocks.as_json(
            include: {
              material: { only: [ :id, :name, :part_number ] },
              warehouse: { only: [ :id, :name ] }
            }
          ),
          meta: { total_count: total_count, page: page, per_page: per_page }
        }
      end

      # GET /api/v1/stocks/:id
      def show
        authorize @stock
        render json: {
          data: @stock.as_json(
            include: {
              material: { only: [ :id, :name, :part_number ] },
              warehouse: { only: [ :id, :name ] },
              stock_transactions: {
                include: { user: { only: [ :id, :name ] } },
                methods: []
              },
              repairs: {
                include: { requested_by: { only: [ :id, :name ] } }
              }
            }
          )
        }
      end

      # POST /api/v1/stocks
      def create
        stock = Stock.new(create_params)
        authorize stock

        ActiveRecord::Base.transaction do
          stock.save!
          record_audit_log("create", stock)

          # 初期数量も台帳（入庫）に残す。台帳を通さない在庫は監査で追えないため
          if stock.quantity.positive?
            initial = stock.stock_transactions.create!(
              user: current_user, transaction_type: "incoming", quantity: stock.quantity,
              reason: "初期登録", transacted_at: Time.current
            )
            record_audit_log("create", initial)
          end
        end

        render json: { data: stock.as_json }, status: :created
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
      end

      # PATCH /api/v1/stocks/:id
      def update
        authorize @stock
        if @stock.update(update_params)
          record_audit_log("update", @stock)
          render json: { data: @stock.as_json }
        else
          render json: { errors: @stock.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def set_stock
        @stock = Stock.includes(
          :material, :warehouse,
          stock_transactions: :user,
          repairs: :requested_by
        ).find(params[:id])
      end

      def create_params
        params.require(:stock).permit(
          :material_id, :warehouse_id, :quantity,
          :purchased_on, :status, :serial_number, :notes
        )
      end

      # 数量・倉庫・資材は入出庫/移動（stock_transactions）でのみ変える。直接書き換えると台帳と残高がずれる
      def update_params
        params.require(:stock).permit(:purchased_on, :status, :serial_number, :notes)
      end
    end
  end
end
