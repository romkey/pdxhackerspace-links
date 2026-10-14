module Unifi
  # Gathers every Network client on every site and merges the integration API's
  # connected clients with the console's known and active client lists, keyed on
  # MAC address.
  #
  # When the console lists cannot be read, only connected clients are returned
  # and the inventory is marked incomplete, so an import does not archive every
  # host that happens to be offline.
  class HostInventory
    Result = Data.define(:records, :complete, :notes) do
      def complete?
        complete
      end
    end

    RADIO_BANDS = {
      "ng" => "2.4 GHz",
      "na" => "5 GHz",
      "6e" => "6 GHz"
    }.freeze

    WIFI_STANDARDS = {
      "be" => "Wi-Fi 7",
      "ax" => "Wi-Fi 6",
      "ac" => "Wi-Fi 5",
      "na" => "Wi-Fi 4",
      "ng" => "Wi-Fi 4",
      "n" => "Wi-Fi 4",
      "a" => "802.11a",
      "b" => "802.11b",
      "g" => "802.11g"
    }.freeze

    def self.build(network_client, sites)
      new(network_client, sites).build
    end

    def initialize(network_client, sites)
      @network_client = network_client
      @sites = sites
      @complete = true
      @notes = []
    end

    def build
      records = @sites.flat_map { |site| site_records(site) }
      Result.new(records: records, complete: @complete, notes: @notes.uniq)
    end

    private

    attr_reader :network_client

    def site_records(site)
      connected = index_by_mac(network_client.clients(site_id: site["id"]), "macAddress")
      known, active, networks = console_lists(site)

      macs = (connected.keys + known.keys + active.keys).uniq
      macs.map do |mac|
        build_record(mac, site, connected[mac], known[mac], active[mac], networks)
      end
    end

    def console_lists(site)
      reference = site["internalReference"].presence
      return incomplete("#{site['name'] || site['id']} has no console reference") if reference.nil?
      return incomplete("the console client lists are unavailable") unless network_client.console_available?

      [
        index_by_mac(network_client.known_clients(site_reference: reference), "mac"),
        index_by_mac(network_client.active_clients(site_reference: reference), "mac"),
        network_client.networks(site_reference: reference).index_by { |network| network["_id"] }
      ]
    rescue Client::RateLimitedError, Client::ConnectionError
      raise
    rescue Client::Error => error
      incomplete(error.message)
    end

    def incomplete(reason)
      @complete = false
      @notes << "only connected hosts were read (#{reason})"
      [ {}, {}, {} ]
    end

    def index_by_mac(entries, key)
      entries.each_with_object({}) do |entry, index|
        mac = Integrations::HardwareAddress.normalize(entry[key])
        index[mac] = entry if mac
      end
    end

    def build_record(mac, site, connected, known, active, networks)
      connected ||= {}
      known ||= {}
      active ||= {}
      pick = ->(key) { [ active[key], known[key] ].find { |value| !value.nil? && value != "" } }
      network = networks[pick.call("network_id")] || {}
      connection_type = connection_type_for(connected, active, known)
      wireless = connection_type == "wireless"

      HostRecord.new(
        ieee_address: mac,
        site_external_id: site["id"],
        site_name: site["name"],
        client_external_id: connected["id"],
        name: known["name"].presence || active["name"].presence || connected["name"].presence,
        hostname: pick.call("hostname"),
        note: known["note"].presence,
        manufacturer: pick.call("oui"),
        ip_address: connected["ipAddress"].presence || active["ip"].presence || known["last_ip"].presence || known["ip"].presence,
        reserved_ip_address: reserved_ip_address(known, active),
        connection_type: connection_type,
        network_name: active["network"].presence || network["name"].presence,
        network_external_id: pick.call("network_id"),
        vlan: integer(active["vlan"] || network["vlan"]),
        ssid: (active["essid"].presence if wireless),
        radio: (RADIO_BANDS[active["radio"]] if wireless),
        wifi_standard: (WIFI_STANDARDS[active["radio_proto"]] if wireless),
        channel: (integer(active["channel"]) if wireless),
        signal: (integer(active["signal"]) if wireless),
        satisfaction: integer(active["satisfaction"]),
        uplink_ieee_address: Integrations::HardwareAddress.normalize(uplink_mac(active, known, wireless)),
        uplink_name: active["last_uplink_name"].presence || known["last_uplink_name"].presence,
        switch_port: (integer(active["sw_port"]) unless wireless),
        online: connected.present? || active.present?,
        guest: connected.dig("access", "type") == "GUEST" || pick.call("is_guest") == true,
        blocked: known["blocked"] == true,
        connected_at: connected_at(connected, active),
        first_seen_at: timestamp(pick.call("first_seen")),
        last_seen_at: timestamp(pick.call("last_seen")),
        payload: { "integration" => connected, "known" => known, "active" => active }.compact_blank
      )
    end

    def connection_type_for(connected, active, known)
      type = connected["type"].to_s.downcase.presence
      return type if UnifiHost::CONNECTION_TYPES.include?(type)

      wired = active.key?("is_wired") ? active["is_wired"] : known["is_wired"]
      return nil if wired.nil?

      wired ? "wired" : "wireless"
    end

    # A reservation only counts while it is switched on; UniFi keeps the address
    # around after it is turned off.
    def reserved_ip_address(known, active)
      [ known, active ].each do |entry|
        next unless entry.key?("use_fixedip")
        return entry["use_fixedip"] ? entry["fixed_ip"].presence : nil
      end
      nil
    end

    def uplink_mac(active, known, wireless)
      direct = wireless ? active["ap_mac"] : active["sw_mac"]
      direct.presence || active["last_uplink_mac"].presence || known["last_uplink_mac"].presence
    end

    def connected_at(connected, active)
      parsed = Time.zone.parse(connected["connectedAt"].to_s) if connected["connectedAt"].present?
      parsed || (Time.current - active["uptime"].to_i if active["uptime"].to_i.positive?)
    rescue ArgumentError
      nil
    end

    def timestamp(value)
      Time.zone.at(value.to_i) if value.to_i.positive?
    end

    def integer(value)
      Integer(value, exception: false) if value.present?
    end
  end
end
