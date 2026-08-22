class CreateZigbee2mqttDevices < ActiveRecord::Migration[8.1]
  def change
    create_table :zigbee2mqtt_devices do |t|
      t.references :zigbee2mqtt_bridge, null: false, foreign_key: true
      t.references :thing, foreign_key: true

      t.string :ieee_address, null: false
      t.string :friendly_name
      t.string :device_type
      t.integer :network_address
      t.string :manufacturer
      t.string :model
      t.text :model_description
      t.string :power_source
      t.string :software_build_id
      t.string :date_code
      t.boolean :supported, default: true, null: false
      t.boolean :disabled, default: false, null: false

      t.datetime :reported_last_seen_at
      t.datetime :first_seen_at, null: false
      t.datetime :last_seen_at, null: false
      t.datetime :archived_at
      t.boolean :ignored, default: false, null: false

      t.jsonb :applied_attributes, default: {}, null: false
      t.jsonb :payload, default: {}, null: false

      t.timestamps
    end

    add_index :zigbee2mqtt_devices, %i[zigbee2mqtt_bridge_id ieee_address],
              unique: true, name: "index_z2m_devices_on_bridge_and_ieee_address"
    add_index :zigbee2mqtt_devices, :archived_at
    add_index :zigbee2mqtt_devices, :ieee_address
  end
end
