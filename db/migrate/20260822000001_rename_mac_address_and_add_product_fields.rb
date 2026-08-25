class RenameMacAddressAndAddProductFields < ActiveRecord::Migration[8.1]
  def change
    rename_column :things, :mac_address, :ieee_address
    rename_column :unifi_devices, :mac_address, :ieee_address

    change_table :things, bulk: true do |t|
      t.string :manufacturer
      t.string :model
      t.string :manufacturer_url
      t.string :integration_source
      t.index :integration_source
    end
  end
end
