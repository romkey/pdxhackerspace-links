module Zigbee2mqtt
  DeviceRecord = Data.define(
    :ieee_address,
    :friendly_name,
    :device_type,
    :network_address,
    :manufacturer,
    :model,
    :model_description,
    :power_source,
    :software_build_id,
    :date_code,
    :supported,
    :disabled,
    :reported_last_seen_at,
    :payload
  ) do
    def to_attributes
      {
        ieee_address: ieee_address,
        friendly_name: friendly_name,
        device_type: device_type,
        network_address: network_address,
        manufacturer: manufacturer,
        model: model,
        model_description: model_description,
        power_source: power_source,
        software_build_id: software_build_id,
        date_code: date_code,
        supported: supported,
        disabled: disabled,
        reported_last_seen_at: reported_last_seen_at,
        payload: payload
      }
    end
  end
end
