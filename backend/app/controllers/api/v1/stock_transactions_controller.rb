module Api
  module V1
    class StockTransactionsController < BaseController
      # POST /api/v1/stock_transactions
      def create
        transaction = StockTransaction.new(transaction_params)
        authorize transaction
        transaction.user = current_user
        transaction.from_warehouse_id = transaction.stock&.warehouse_id if transaction.transfer?

        ActiveRecord::Base.transaction do
          transaction.save!
          record_audit_log("create", transaction)

          stock = transaction.stock
          case transaction.transaction_type
          when "incoming"
            stock.update!(quantity: stock.quantity + transaction.quantity)
          when "outgoing"
            new_qty = stock.quantity - transaction.quantity
            raise ActiveRecord::RecordInvalid.new(stock), "在庫数が不足しています" if new_qty < 0
            stock.update!(quantity: new_qty)
          when "disposal"
            new_qty = stock.quantity - transaction.quantity
            raise ActiveRecord::RecordInvalid.new(stock), "在庫数が不足しています" if new_qty < 0
            stock.update!(quantity: new_qty, status: new_qty.zero? ? "disposed" : stock.status)
          when "transfer"
            raise ActiveRecord::RecordInvalid.new(stock), "移動先倉庫を指定してください" if transaction.to_warehouse_id.blank?
            raise ActiveRecord::RecordInvalid.new(stock), "移動元と移動先の倉庫が同じです" if transaction.to_warehouse_id == stock.warehouse_id

            new_qty = stock.quantity - transaction.quantity
            raise ActiveRecord::RecordInvalid.new(stock), "在庫数が不足しています" if new_qty < 0
            stock.update!(quantity: new_qty)

            Stock.create!(
              material_id: stock.material_id,
              warehouse_id: transaction.to_warehouse_id,
              quantity: transaction.quantity,
              purchased_on: stock.purchased_on,
              status: stock.status,
              notes: stock.notes
            )
          end
        end

        render json: {
          data: transaction.as_json(include: { user: { only: [ :id, :name ] } })
        }, status: :created
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: [ e.message ] }, status: :unprocessable_entity
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
