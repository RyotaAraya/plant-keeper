class CreateInstruments < ActiveRecord::Migration[7.1]
  def change
    create_table :instruments do |t|
      t.string :tag_number, null: false
      t.string :instrument_type
      t.references :equipment, null: false, foreign_key: true
      t.references :service, foreign_key: true
      t.references :line_class, foreign_key: true
      t.string :location
      t.text :notes

      t.timestamps
    end

    add_index :instruments, :tag_number, unique: true
  end
end
