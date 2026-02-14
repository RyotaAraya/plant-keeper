class CreateOrders < ActiveRecord::Migration[7.1]
  def change
    create_table :orders do |t|
      t.references :material, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :quantity, null: false
      t.decimal :unit_price
      t.string :supplier_name
      t.string :supplier_link
      t.string :status, null: false, default: "draft"
      t.date :ordered_on, null: false
      t.date :received_on
      t.text :notes

      t.timestamps
    end

    add_index :orders, :status
  end
end
