class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users do |t|
      ## Devise database authenticatable
      t.string :email, null: false
      t.string :encrypted_password, null: false, default: ""

      ## Devise recoverable
      t.string :reset_password_token
      t.datetime :reset_password_sent_at

      ## Devise rememberable
      t.datetime :remember_created_at

      ## Application columns
      t.string :name, null: false
      t.string :role, null: false, default: "worker"
      t.references :department, foreign_key: true
      t.integer :join_year
      t.string :home_prefecture
      t.string :previous_company
      t.boolean :is_active, null: false, default: true
      t.date :deactivated_on

      ## JWT revocation strategy
      t.string :jti, null: false

      t.timestamps
    end

    add_index :users, :email, unique: true
    add_index :users, :jti, unique: true
    add_index :users, :reset_password_token, unique: true
    add_index :users, :role
    add_index :users, :is_active
  end
end
