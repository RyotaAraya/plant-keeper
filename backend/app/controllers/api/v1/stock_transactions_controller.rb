module Api
  module V1
    class StockTransactionsController < BaseController
      # POST /api/v1/stock_transactions
      def create
        transaction = StockTransaction.new(transaction_params)
        authorize transaction
        transaction.user = current_user

        ActiveRecord::Base.transaction do
          # 同時に入出庫されても数量が狂わないよう、在庫行を先にロックしてから読む
          stock = Stock.lock.find_by(id: transaction.stock_id)
          transaction.stock = stock
          transaction.from_warehouse_id = stock&.warehouse_id if transaction.transfer?
          transaction.save!
          record_audit_log("create", transaction)

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

            # 移動先に同じロット（資材・購入日・状態が同じ、シリアル無し）があれば数量を足し、行を増やさない
            destination = Stock.lock.find_or_initialize_by(
              material_id: stock.material_id,
              warehouse_id: transaction.to_warehouse_id,
              purchased_on: stock.purchased_on,
              status: stock.status,
              serial_number: stock.serial_number.presence
            )
            destination.notes ||= stock.notes
            destination.quantity += transaction.quantity
            destination.save!
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
