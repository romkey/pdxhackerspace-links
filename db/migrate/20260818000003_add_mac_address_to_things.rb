class AddMacAddressToThings < ActiveRecord::Migration[8.1]
  def change
    add_column :things, :mac_address, :string
    add_index :things, :mac_address, unique: true, where: "mac_address IS NOT NULL"
  end
end
