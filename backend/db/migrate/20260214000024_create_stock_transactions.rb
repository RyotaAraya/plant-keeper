class CreateStockTransactions < ActiveRecord::Migration[7.1]
  def change
    create_table :stock_transactions do |t|
      t.references :stock, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :transaction_type, null: false
      t.integer :quantity, null: false
      t.bigint :from_warehouse_id
      t.bigint :to_warehouse_id
      t.string :reason
      t.datetime :transacted_at, null: false

      t.timestamps
    end

    add_index :stock_transactions, :transaction_type
    add_foreign_key :stock_transactions, :warehouses, column: :from_warehouse_id
    add_foreign_key :stock_transactions, :warehouses, column: :to_warehouse_id
  end
end
