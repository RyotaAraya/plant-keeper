class CreateTroubleResponses < ActiveRecord::Migration[7.1]
  def change
    create_table :trouble_responses do |t|
      t.references :trouble, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :response_type, null: false
      t.text :description, null: false
      t.text :used_materials
      t.datetime :responded_at, null: false

      t.timestamps
    end
  end
end
