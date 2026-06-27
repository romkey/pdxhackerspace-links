class AddMatomoToSiteSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :site_settings, :matomo_url, :string
    add_column :site_settings, :matomo_site_id, :string
  end
end
