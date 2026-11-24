module Settings
  class Zigbee2mqttDevicesController < BaseController
    def update
      zigbee2mqtt_device = Zigbee2mqttDevice.find(params[:id])
      ignored = ActiveModel::Type::Boolean.new.cast(params[:ignored])

      if ignored
        zigbee2mqtt_device.update!(ignored: true, thing: nil)
        notice = "#{zigbee2mqtt_device.display_name} will be skipped by future imports."
      else
        zigbee2mqtt_device.update!(ignored: false, auto_link: true)
        Integrations::SyncThing.call(
          integration_device: zigbee2mqtt_device,
          auto_create: zigbee2mqtt_device.zigbee2mqtt_bridge.auto_create_things?
        )
        notice = "#{zigbee2mqtt_device.display_name} will be imported again."
      end

      redirect_to settings_zigbee2mqtt_bridge_path(zigbee2mqtt_device.zigbee2mqtt_bridge), notice: notice
    end

    def unlink
      zigbee2mqtt_device = Zigbee2mqttDevice.find(params[:id])
      thing = zigbee2mqtt_device.thing
      Integrations::Unlink.call(zigbee2mqtt_device)

      redirect_back_or_to settings_zigbee2mqtt_bridge_path(zigbee2mqtt_device.zigbee2mqtt_bridge),
                          notice: unlink_notice(zigbee2mqtt_device, thing)
    end

    def link
      zigbee2mqtt_device = Zigbee2mqttDevice.find(params[:id])
      Integrations::Relink.call(
        record: zigbee2mqtt_device,
        auto_create: zigbee2mqtt_device.zigbee2mqtt_bridge.auto_create_things?
      )

      redirect_to settings_zigbee2mqtt_bridge_path(zigbee2mqtt_device.zigbee2mqtt_bridge),
                  notice: link_notice(zigbee2mqtt_device.reload)
    end
  end
end
