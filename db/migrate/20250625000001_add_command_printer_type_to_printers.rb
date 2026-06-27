class AddCommandPrinterTypeToPrinters < ActiveRecord::Migration[8.1]
  def change
    add_column :printers, :printer_type, :string, null: false, default: "cups"
    add_column :printers, :label_height_mm, :integer
    add_column :printers, :print_command, :text

    change_column_null :printers, :cups_name, true
    change_column_null :printers, :cups_server, true
    change_column_null :printers, :page_size, true

    add_index :printers, :printer_type
  end
end
