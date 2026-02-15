class CreateCompaniesAndLinkUsers < ActiveRecord::Migration[7.2]
  def up
    create_table :companies do |t|
      t.string :name, null: false
      t.string :company_type, null: false, default: "owner"
      t.boolean :is_active, null: false, default: true
      t.timestamps
    end

    add_index :companies, :company_type

    # users に company_id FK を追加
    add_reference :users, :company, foreign_key: true

    # 既存データ移行: company 文字列から companies レコードを作成
    execute <<~SQL
      INSERT INTO companies (name, company_type, created_at, updated_at)
      SELECT DISTINCT company, 'contractor', NOW(), NOW()
      FROM users
      WHERE company IS NOT NULL AND company != '';
    SQL

    # users.company_id を紐づけ
    execute <<~SQL
      UPDATE users
      SET company_id = companies.id
      FROM companies
      WHERE users.company = companies.name;
    SQL

    # company 文字列カラムを削除
    remove_column :users, :company
  end

  def down
    add_column :users, :company, :string

    execute <<~SQL
      UPDATE users
      SET company = companies.name
      FROM companies
      WHERE users.company_id = companies.id;
    SQL

    remove_reference :users, :company
    drop_table :companies
  end
end
