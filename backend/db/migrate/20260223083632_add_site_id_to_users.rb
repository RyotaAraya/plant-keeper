class AddSiteIdToUsers < ActiveRecord::Migration[8.0]
  def change
    add_reference :users, :site, null: true, foreign_key: true
  end
end
