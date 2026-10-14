class AddHostsEnabledToUnifiControllers < ActiveRecord::Migration[8.1]
  def change
    add_column :unifi_controllers, :hosts_enabled, :boolean, null: false, default: true
  end
end
