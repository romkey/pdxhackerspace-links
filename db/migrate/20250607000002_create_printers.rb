class CreatePrinters < ActiveRecord::Migration[8.1]
  def change
    create_table :printers do |t|
      t.string :name, null: false
      t.string :cups_name, null: false
      t.string :page_size, null: false
      t.text :description
      t.boolean :enabled, null: false, default: true

      t.timestamps
    end

    add_index :printers, :cups_name, unique: true
    add_index :printers, :name
    add_index :printers, :enabled
  end
end
