module Settings
  class UnifiDevicesController < BaseController
    # Ignoring a device unlinks its thing and stops future imports from recreating one.
    def update
      unifi_device = UnifiDevice.find(params[:id])
      ignored = ActiveModel::Type::Boolean.new.cast(params[:ignored])

      if ignored
        unifi_device.update!(ignored: true, thing: nil)
        notice = "#{unifi_device.display_name} will be skipped by future imports."
      else
        unifi_device.update!(ignored: false)
        Unifi::SyncThing.call(
          unifi_device: unifi_device,
          auto_create: unifi_device.unifi_controller.auto_create_things?
        )
        notice = "#{unifi_device.display_name} will be imported again."
      end

      redirect_to settings_unifi_controller_path(unifi_device.unifi_controller), notice: notice
    end
  end
end
