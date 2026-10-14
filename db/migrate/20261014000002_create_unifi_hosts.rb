# Every client a UniFi Network console knows about, connected or not. Hosts are
# never turned into things; they only link to a thing that already shares their
# MAC or IP address.
class CreateUnifiHosts < ActiveRecord::Migration[8.1]
  def change
    create_table :unifi_hosts do |t|
      t.references :unifi_controller, null: false, foreign_key: true
      t.references :thing, foreign_key: true
      t.string :ieee_address, null: false
      t.string :site_external_id
      t.string :site_name
      t.string :client_external_id
      t.string :name
      t.string :hostname
      t.text :note
      t.string :manufacturer
      t.string :ip_address
      t.string :reserved_ip_address
      t.string :connection_type
      t.string :network_name
      t.string :network_external_id
      t.integer :vlan
      t.string :ssid
      t.string :radio
      t.string :wifi_standard
      t.integer :channel
      t.integer :signal
      t.integer :satisfaction
      t.string :uplink_ieee_address
      t.string :uplink_name
      t.integer :switch_port
      t.boolean :online, null: false, default: false
      t.boolean :guest, null: false, default: false
      t.boolean :blocked, null: false, default: false
      t.boolean :ignored, null: false, default: false
      t.datetime :connected_at
      t.datetime :first_seen_at
      t.datetime :last_seen_at
      t.datetime :imported_at, null: false
      t.datetime :archived_at
      t.jsonb :payload, null: false, default: {}
      t.jsonb :applied_attributes, null: false, default: {}

      t.timestamps
    end

    add_index :unifi_hosts, %i[unifi_controller_id site_external_id ieee_address],
              unique: true,
              name: "index_unifi_hosts_on_controller_site_and_ieee_address"
    add_index :unifi_hosts, :ieee_address
    add_index :unifi_hosts, :ip_address
    add_index :unifi_hosts, :connection_type
    add_index :unifi_hosts, :archived_at
  end
end
