module Unifi
  # A Network client merged from the integration API and the console's own
  # client lists, normalized into the shape stored on UnifiHost.
  HostRecord = Data.define(
    :ieee_address,
    :site_external_id,
    :site_name,
    :client_external_id,
    :name,
    :hostname,
    :note,
    :manufacturer,
    :ip_address,
    :reserved_ip_address,
    :connection_type,
    :network_name,
    :network_external_id,
    :vlan,
    :ssid,
    :radio,
    :wifi_standard,
    :channel,
    :signal,
    :satisfaction,
    :uplink_ieee_address,
    :uplink_name,
    :switch_port,
    :online,
    :guest,
    :blocked,
    :connected_at,
    :first_seen_at,
    :last_seen_at,
    :payload
  ) do
    def initialize(ieee_address:, site_external_id: nil, site_name: nil, client_external_id: nil, name: nil,
                   hostname: nil, note: nil, manufacturer: nil, ip_address: nil, reserved_ip_address: nil,
                   connection_type: nil, network_name: nil, network_external_id: nil, vlan: nil, ssid: nil,
                   radio: nil, wifi_standard: nil, channel: nil, signal: nil, satisfaction: nil,
                   uplink_ieee_address: nil, uplink_name: nil, switch_port: nil, online: false, guest: false,
                   blocked: false, connected_at: nil, first_seen_at: nil, last_seen_at: nil, payload: {})
      super
    end

    def to_attributes
      to_h.except(:ieee_address, :site_external_id)
    end
  end
end
