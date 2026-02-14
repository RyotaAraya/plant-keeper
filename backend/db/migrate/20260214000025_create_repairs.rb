class CreateRepairs < ActiveRecord::Migration[7.1]
  def change
    create_table :repairs do |t|
      t.references :stock, null: false, foreign_key: true
      t.references :trouble, foreign_key: true
      t.references :requested_by, null: false, foreign_key: { to_table: :users }
      t.string :status, null: false, default: "pending"
      t.string :repair_vendor
      t.date :shipped_on
      t.date :completed_on
      t.date :received_on
      t.decimal :repair_cost
      t.decimal :shipping_cost
      t.string :disposition
      t.text :notes

      t.timestamps
    end

    add_index :repairs, :status
  end
end
