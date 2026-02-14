module Api
  module V1
    class StocksController < BaseController
      before_action :set_stock, only: [:show, :update]

      # GET /api/v1/stocks
      def index
        stocks = Stock.includes(:material, :warehouse).all
        stocks = stocks.where(material_id: params[:material_id]) if params[:material_id].present?
        stocks = stocks.where(warehouse_id: params[:warehouse_id]) if params[:warehouse_id].present?
        stocks = stocks.where(status: params[:status]) if params[:status].present?

        stocks = stocks.order(purchased_on: :asc)
        total_count = stocks.count

        page = (params[:page] || 1).to_i
        per_page = (params[:per_page] || 25).to_i
        stocks = stocks.limit(per_page).offset((page - 1) * per_page)

        render json: {
          data: stocks.as_json(
            include: {
              material: { only: [:id, :name, :part_number] },
              warehouse: { only: [:id, :name] }
            }
          ),
          meta: { total_count: total_count, page: page, per_page: per_page }
        }
      end

      # GET /api/v1/stocks/:id
      def show
        render json: {
          data: @stock.as_json(
            include: {
              material: { only: [:id, :name, :part_number] },
              warehouse: { only: [:id, :name] },
              stock_transactions: {
                include: { user: { only: [:id, :name] } },
                methods: []
              },
              repairs: {
                include: { requested_by: { only: [:id, :name] } }
              }
            }
          )
        }
      end

      # POST /api/v1/stocks
      def create
        stock = Stock.new(stock_params)
        if stock.save
          render json: { data: stock.as_json }, status: :created
        else
          render json: { errors: stock.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/stocks/:id
      def update
        if @stock.update(stock_params)
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

      def stock_params
        params.require(:stock).permit(
          :material_id, :warehouse_id, :quantity,
          :purchased_on, :status, :serial_number, :notes
        )
      end
    end
  end
end
