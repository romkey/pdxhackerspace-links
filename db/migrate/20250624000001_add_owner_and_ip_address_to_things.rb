class AddOwnerAndIpAddressToThings < ActiveRecord::Migration[8.1]
  def change
    add_column :things, :owner, :string
    add_column :things, :ip_address, :string
  end
end
