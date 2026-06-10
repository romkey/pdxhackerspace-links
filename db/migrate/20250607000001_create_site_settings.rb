class CreateSiteSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :site_settings do |t|
      t.string :cups_server, null: false, default: "localhost:631"

      t.timestamps
    end
  end
end
