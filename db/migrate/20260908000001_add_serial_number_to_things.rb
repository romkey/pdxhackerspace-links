class AddSerialNumberToThings < ActiveRecord::Migration[8.1]
  def change
    add_column :things, :serial_number, :string
    add_index :things, :serial_number, where: "serial_number IS NOT NULL"
  end
end
