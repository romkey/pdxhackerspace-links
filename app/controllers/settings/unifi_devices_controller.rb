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
        unifi_device.update!(ignored: false, auto_link: true)
        Unifi::SyncThing.call(
          unifi_device: unifi_device,
          auto_create: unifi_device.unifi_controller.auto_create_things?
        )
        notice = "#{unifi_device.display_name} will be imported again."
      end

      redirect_to settings_unifi_controller_path(unifi_device.unifi_controller), notice: notice
    end

    # Detaches the thing and stops later imports from linking this device again.
    def unlink
      unifi_device = UnifiDevice.find(params[:id])
      thing = unifi_device.thing
      Integrations::Unlink.call(unifi_device)

      redirect_back_or_to settings_unifi_controller_path(unifi_device.unifi_controller),
                          notice: unlink_notice(unifi_device, thing)
    end

    def link
      unifi_device = UnifiDevice.find(params[:id])
      Integrations::Relink.call(
        record: unifi_device,
        auto_create: unifi_device.unifi_controller.auto_create_things?
      )

      redirect_to settings_unifi_controller_path(unifi_device.unifi_controller),
                  notice: link_notice(unifi_device.reload)
    end
  end
end
