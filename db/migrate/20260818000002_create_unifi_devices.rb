class CreateUnifiDevices < ActiveRecord::Migration[8.1]
  def change
    create_table :unifi_devices do |t|
      t.references :unifi_controller, null: false, foreign_key: true
      t.references :thing, foreign_key: true
      t.string :source, null: false
      t.string :external_id, null: false
      t.string :kind, null: false
      t.string :name
      t.string :model
      t.string :mac_address
      t.string :ip_address
      t.string :firmware_version
      t.string :state
      t.string :site_external_id
      t.string :site_name
      t.jsonb :payload, null: false, default: {}
      t.jsonb :applied_attributes, null: false, default: {}
      t.boolean :ignored, null: false, default: false
      t.datetime :first_seen_at, null: false
      t.datetime :last_seen_at, null: false
      t.datetime :archived_at

      t.timestamps
    end

    add_index :unifi_devices, %i[unifi_controller_id source external_id],
              unique: true,
              name: "index_unifi_devices_on_controller_source_and_external_id"
    add_index :unifi_devices, :mac_address
    add_index :unifi_devices, :source
    add_index :unifi_devices, :archived_at
  end
end
