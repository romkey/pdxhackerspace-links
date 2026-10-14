class AddReservedIpAddressToThings < ActiveRecord::Migration[8.1]
  def change
    add_column :things, :reserved_ip_address, :string
  end
end
