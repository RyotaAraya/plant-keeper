class AddStockChecksAndScopeInstrumentTag < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :stocks, "quantity >= 0", name: "stocks_quantity_non_negative"
    add_check_constraint :stock_transactions, "quantity > 0", name: "stock_transactions_quantity_positive"

    # タグ番号の一意性は「拠点内」。拠点をまたぐ条件はDBの一意制約で表せないためモデルで検証し、
    # DBは設備内の重複だけを保証する（別拠点で同じタグ番号を使えるよう、全体の一意制約は外す）
    remove_index :instruments, column: :tag_number, unique: true
    add_index :instruments, :tag_number
    add_index :instruments, [ :equipment_id, :tag_number ], unique: true
  end
end
