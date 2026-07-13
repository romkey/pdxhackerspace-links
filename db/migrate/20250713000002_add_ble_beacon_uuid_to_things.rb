class AddBleBeaconUuidToThings < ActiveRecord::Migration[8.1]
  def change
    add_column :things, :ble_beacon_uuid, :string
    add_index :things, :ble_beacon_uuid, unique: true, where: "ble_beacon_uuid IS NOT NULL"
  end
end
