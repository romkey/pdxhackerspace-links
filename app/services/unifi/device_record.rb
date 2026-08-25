module Unifi
  # A device from either UniFi application, normalized into the shape stored on
  # UnifiDevice. Protect devices carry no IP address or firmware version.
  DeviceRecord = Data.define(
    :source,
    :external_id,
    :kind,
    :name,
    :model,
    :ieee_address,
    :ip_address,
    :firmware_version,
    :state,
    :site_external_id,
    :site_name,
    :payload
  ) do
    def initialize(source:, external_id:, kind:, name: nil, model: nil, ieee_address: nil, ip_address: nil,
                   firmware_version: nil, state: nil, site_external_id: nil, site_name: nil, payload: {})
      super
    end

    def to_attributes
      {
        kind: kind,
        name: name,
        model: model,
        ieee_address: ieee_address,
        ip_address: ip_address,
        firmware_version: firmware_version,
        state: state,
        site_external_id: site_external_id,
        site_name: site_name,
        payload: payload
      }
    end
  end
end
