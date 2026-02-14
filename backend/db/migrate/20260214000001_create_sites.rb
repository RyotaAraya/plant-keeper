class CreateSites < ActiveRecord::Migration[7.1]
  def change
    create_table :sites do |t|
      t.string :name, null: false
      t.string :prefecture
      t.string :address
      t.boolean :is_active, null: false, default: true
      t.date :closed_on

      t.timestamps
    end

    add_index :sites, :is_active
  end
end
