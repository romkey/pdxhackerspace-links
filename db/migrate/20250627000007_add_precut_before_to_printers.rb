class AddPrecutBeforeToPrinters < ActiveRecord::Migration[8.1]
  def change
    add_column :printers, :precut_before, :boolean, default: false, null: false

    reversible do |dir|
      dir.up do
        execute <<~SQL.squish
          UPDATE printers SET precut_before = true WHERE printer_type = 'command'
        SQL
      end
    end
  end
end
