# A client the UniFi Network application knows about — anything that has ever
# joined the network, not just adopted UniFi hardware. Hosts never create
# things; they link to a thing that already shares their MAC or IP address.
class UnifiHost < ApplicationRecord
  include IntegrationDevice

  CONNECTION_TYPES = %w[wired wireless vpn teleport].freeze
  CONNECTION_TYPE_LABELS = {
    "wired" => "Wired",
    "wireless" => "Wi-Fi",
    "vpn" => "VPN",
    "teleport" => "Teleport"
  }.freeze

  belongs_to :unifi_controller
  belongs_to :thing, optional: true

  validates :ieee_address, presence: true,
                           uniqueness: { scope: %i[unifi_controller_id site_external_id] }
  validates :connection_type, inclusion: { in: CONNECTION_TYPES }, allow_nil: true
  validates :imported_at, presence: true

  scope :ordered, -> { order(Arel.sql("LOWER(COALESCE(unifi_hosts.name, unifi_hosts.hostname, unifi_hosts.ieee_address))")) }
  scope :linked, -> { where.not(thing_id: nil) }
  scope :online, -> { where(online: true) }
  scope :reserved, -> { where.not(reserved_ip_address: [ nil, "" ]) }
  scope :wireless, -> { where(connection_type: "wireless") }
  scope :wired, -> { where(connection_type: "wired") }

  scope :search, lambda { |query|
    term = query.to_s.strip
    next all if term.blank?

    pattern = "%#{sanitize_sql_like(term)}%"
    where(
      "unifi_hosts.name ILIKE :q OR unifi_hosts.hostname ILIKE :q OR unifi_hosts.ieee_address ILIKE :q OR " \
      "unifi_hosts.ip_address ILIKE :q OR unifi_hosts.reserved_ip_address ILIKE :q OR " \
      "unifi_hosts.manufacturer ILIKE :q OR unifi_hosts.note ILIKE :q",
      q: pattern
    )
  }

  def integration_source
    "unifi"
  end

  def display_name
    name.presence || hostname.presence || ieee_address_display
  end

  def ieee_address_display
    Integrations::HardwareAddress.display(ieee_address)
  end

  def connection_label
    CONNECTION_TYPE_LABELS[connection_type]
  end

  def wireless?
    connection_type == "wireless"
  end

  def reserved?
    reserved_ip_address.present?
  end

  # Where the host plugs in: an access point and SSID for Wi-Fi, a switch and
  # port for a wired client.
  def uplink_label
    uplink = uplink_name.presence || Integrations::HardwareAddress.display(uplink_ieee_address).presence
    return nil if uplink.blank?

    switch_port.present? ? "#{uplink} port #{switch_port}" : uplink
  end

  def signal_label
    "#{signal} dBm" if signal.present?
  end
end
