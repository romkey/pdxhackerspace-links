class AddNetworkNameToThings < ActiveRecord::Migration[8.1]
  def change
    add_column :things, :network_name, :string
  end
end
