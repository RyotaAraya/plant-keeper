class AddSealFluidToInstruments < ActiveRecord::Migration[8.0]
  def change
    add_column :instruments, :seal_fluid, :string
  end
end
