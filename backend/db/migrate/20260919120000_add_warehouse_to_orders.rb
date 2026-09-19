class AddWarehouseToOrders < ActiveRecord::Migration[8.0]
  def change
    # 受領時に在庫として入庫する倉庫（受領前は未指定）
    add_reference :orders, :warehouse, foreign_key: true
  end
end
