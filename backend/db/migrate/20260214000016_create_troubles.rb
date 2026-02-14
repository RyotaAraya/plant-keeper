class CreateTroubles < ActiveRecord::Migration[7.1]
  def change
    create_table :troubles do |t|
      t.bigint :inspection_item_id
      t.references :equipment, null: false, foreign_key: true
      t.references :instrument, foreign_key: true
      t.references :reported_by, null: false, foreign_key: { to_table: :users }
      t.references :assigned_to, foreign_key: { to_table: :users }
      t.string :title, null: false
      t.text :description
      t.string :status, null: false, default: "open"
      t.string :priority, null: false, default: "medium"
      t.datetime :reported_at, null: false
      t.datetime :resolved_at

      t.timestamps
    end

    add_index :troubles, :status
    add_index :troubles, :priority
  end
end
