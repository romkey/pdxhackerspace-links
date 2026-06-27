class AddRemoteServerAndAveryToPrinters < ActiveRecord::Migration[8.1]
  def up
    add_column :printers, :cups_server, :string
    add_column :printers, :avery_template, :string

    default_server = select_value("SELECT cups_server FROM site_settings ORDER BY id LIMIT 1") || "localhost:631"
    execute <<~SQL.squish
      UPDATE printers SET cups_server = #{connection.quote(default_server)}
    SQL

    change_column_null :printers, :cups_server, false

    remove_index :printers, :cups_name
    add_index :printers, %i[cups_server cups_name], unique: true
    add_index :printers, :cups_server
  end

  def down
    remove_index :printers, :cups_server
    remove_index :printers, column: %i[cups_server cups_name]
    add_index :printers, :cups_name, unique: true

    remove_column :printers, :avery_template
    remove_column :printers, :cups_server
  end
end
