class CreateLineClasses < ActiveRecord::Migration[7.1]
  def change
    create_table :line_classes do |t|
      t.string :code, null: false
      t.text :description

      t.timestamps
    end

    add_index :line_classes, :code, unique: true
  end
end
