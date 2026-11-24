class AddAutoLinkToIntegrationRecords < ActiveRecord::Migration[8.1]
  def change
    add_column :unifi_devices, :auto_link, :boolean, null: false, default: true
    add_column :unifi_hosts, :auto_link, :boolean, null: false, default: true
    add_column :zigbee2mqtt_devices, :auto_link, :boolean, null: false, default: true
    add_column :prusa_connect_printers, :auto_link, :boolean, null: false, default: true
  end
end
