class CreateStocks < ActiveRecord::Migration[7.1]
  def change
    create_table :stocks do |t|
      t.references :material, null: false, foreign_key: true
      t.references :warehouse, null: false, foreign_key: true
      t.integer :quantity, null: false, default: 0
      t.date :purchased_on
      t.string :status, null: false, default: "available"
      t.string :serial_number
      t.text :notes

      t.timestamps
    end

    add_index :stocks, :status
  end
end
