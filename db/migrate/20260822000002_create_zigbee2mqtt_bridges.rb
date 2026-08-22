class CreateZigbee2mqttBridges < ActiveRecord::Migration[8.1]
  def change
    create_table :zigbee2mqtt_bridges do |t|
      t.string :name, null: false
      t.text :description
      t.boolean :enabled, default: true, null: false

      t.string :mqtt_host, null: false
      t.integer :mqtt_port, default: 1883, null: false
      t.string :mqtt_username
      t.text :mqtt_password
      t.boolean :mqtt_tls, default: false, null: false
      t.string :base_topic, default: "zigbee2mqtt", null: false

      t.boolean :auto_create_things, default: true, null: false
      t.boolean :skip_disabled_devices, default: true, null: false
      t.integer :last_seen_limit_days
      t.boolean :import_unknown_last_seen, default: true, null: false

      t.datetime :last_synced_at
      t.string :last_sync_status
      t.text :last_sync_message

      t.timestamps
    end

    add_index :zigbee2mqtt_bridges, :name, unique: true
    add_index :zigbee2mqtt_bridges, :enabled
  end
end
