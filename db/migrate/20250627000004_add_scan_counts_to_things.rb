class AddScanCountsToThings < ActiveRecord::Migration[8.1]
  def change
    add_column :things, :qr_scan_count, :integer, default: 0, null: false
    add_column :things, :nfc_scan_count, :integer, default: 0, null: false
  end
end
