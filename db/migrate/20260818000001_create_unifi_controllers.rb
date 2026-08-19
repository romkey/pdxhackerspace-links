class CreateUnifiControllers < ActiveRecord::Migration[8.1]
  def change
    create_table :unifi_controllers do |t|
      t.string :name, null: false
      t.string :host, null: false
      t.integer :port, null: false, default: 443
      t.text :api_key, null: false
      t.boolean :verify_tls, null: false, default: false
      t.boolean :network_enabled, null: false, default: true
      t.boolean :protect_enabled, null: false, default: true
      t.boolean :auto_create_things, null: false, default: true
      t.boolean :enabled, null: false, default: true
      t.text :description
      t.datetime :last_synced_at
      t.string :last_sync_status
      t.text :last_sync_message

      t.timestamps
    end

    add_index :unifi_controllers, :name, unique: true
    add_index :unifi_controllers, %i[host port], unique: true
    add_index :unifi_controllers, :enabled
  end
end
