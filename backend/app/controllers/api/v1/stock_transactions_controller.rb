module Api
  module V1
    class StockTransactionsController < BaseController
      # POST /api/v1/stock_transactions
      def create
        transaction = StockTransaction.new(transaction_params)
        transaction.user = current_user

        ActiveRecord::Base.transaction do
          transaction.save!

          stock = transaction.stock
          case transaction.transaction_type
          when 'incoming'
            stock.update!(quantity: stock.quantity + transaction.quantity)
          when 'outgoing'
            new_qty = stock.quantity - transaction.quantity
            raise ActiveRecord::RecordInvalid.new(stock), "在庫数が不足しています" if new_qty < 0
            stock.update!(quantity: new_qty)
          when 'disposal'
            new_qty = stock.quantity - transaction.quantity
            raise ActiveRecord::RecordInvalid.new(stock), "在庫数が不足しています" if new_qty < 0
            stock.update!(quantity: new_qty, status: new_qty.zero? ? 'disposed' : stock.status)
          end
        end

        render json: {
          data: transaction.as_json(include: { user: { only: [:id, :name] } })
        }, status: :created
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: [e.message] }, status: :unprocessable_entity
      end

      private

      def transaction_params
        params.require(:stock_transaction).permit(
          :stock_id, :transaction_type, :quantity,
          :from_warehouse_id, :to_warehouse_id, :reason, :transacted_at
        )
      end
    end
  end
end
