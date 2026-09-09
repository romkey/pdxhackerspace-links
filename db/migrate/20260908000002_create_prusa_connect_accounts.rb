class CreatePrusaConnectAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :prusa_connect_accounts do |t|
      t.string :name, null: false
      t.text :description
      t.boolean :enabled, default: true, null: false
      t.boolean :auto_create_things, default: true, null: false

      t.text :refresh_token
      t.text :access_token
      t.datetime :access_token_expires_at

      t.datetime :last_synced_at
      t.string :last_sync_status
      t.text :last_sync_message

      t.timestamps
    end

    add_index :prusa_connect_accounts, :name, unique: true
    add_index :prusa_connect_accounts, :enabled
  end
end
