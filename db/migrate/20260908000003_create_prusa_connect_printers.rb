class CreatePrusaConnectPrinters < ActiveRecord::Migration[8.1]
  def change
    create_table :prusa_connect_printers do |t|
      t.references :prusa_connect_account, null: false, foreign_key: true
      t.references :thing, foreign_key: true

      t.string :external_id, null: false
      t.string :name
      t.string :printer_model
      t.string :printer_type_name
      t.string :serial_number
      t.string :firmware
      t.string :ieee_address
      t.string :hostname
      t.string :location
      t.string :team_name
      t.string :state

      t.datetime :first_seen_at, null: false
      t.datetime :last_seen_at, null: false
      t.datetime :archived_at
      t.boolean :ignored, default: false, null: false

      t.jsonb :applied_attributes, default: {}, null: false
      t.jsonb :payload, default: {}, null: false

      t.timestamps
    end

    add_index :prusa_connect_printers, %i[prusa_connect_account_id external_id],
              unique: true, name: "index_pc_printers_on_account_and_external_id"
    add_index :prusa_connect_printers, :archived_at
    add_index :prusa_connect_printers, :ieee_address
  end
end
