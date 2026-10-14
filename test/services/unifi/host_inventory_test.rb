require "test_helper"

class Unifi::HostInventoryTest < ActiveSupport::TestCase
  SITE = { "id" => "site-1", "internalReference" => "default", "name" => "Default" }.freeze
  SITES_PATH = "/proxy/network/integration/v1/sites?limit=200&offset=0".freeze
  CLIENTS_PATH = "/proxy/network/integration/v1/sites/site-1/clients?limit=200&offset=0".freeze
  KNOWN_PATH = "/proxy/network/api/s/default/rest/user".freeze
  ACTIVE_PATH = "/proxy/network/api/s/default/stat/sta".freeze
  NETWORKS_PATH = "/proxy/network/api/s/default/rest/networkconf".freeze

  def console(items)
    { "meta" => { "rc" => "ok" }, "data" => items }
  end

  def inventory(responses)
    Unifi::NetworkClient.for(unifi_controllers(:udm), transport: unifi_transport(responses)).host_inventory
  end

  def full_responses(connected: [], known: [], active: [], networks: [])
    {
      SITES_PATH => [ 200, unifi_page([ SITE ]) ],
      CLIENTS_PATH => [ 200, unifi_page(connected) ],
      KNOWN_PATH => [ 200, console(known) ],
      ACTIVE_PATH => [ 200, console(active) ],
      NETWORKS_PATH => [ 200, console(networks) ]
    }
  end

  test "merges a wireless client from every list" do
    result = inventory(full_responses(
      connected: [ {
        "id" => "client-1", "name" => "Laptop", "type" => "WIRELESS", "ipAddress" => "192.168.1.50",
        "macAddress" => "3C:22:FB:11:22:33", "connectedAt" => "2026-10-14T08:00:00Z", "access" => { "type" => "DEFAULT" }
      } ],
      known: [ {
        "_id" => "user-1", "mac" => "3c:22:fb:11:22:33", "name" => "Romkey laptop", "note" => "Loaner",
        "use_fixedip" => true, "fixed_ip" => "192.168.1.50", "network_id" => "net-1",
        "first_seen" => 1_700_000_000, "last_seen" => 1_760_000_000, "blocked" => false
      } ],
      active: [ {
        "mac" => "3c:22:fb:11:22:33", "hostname" => "romkey-laptop", "oui" => "Apple, Inc.", "ip" => "192.168.1.50",
        "is_wired" => false, "essid" => "Hackerspace", "radio" => "na", "radio_proto" => "ax", "channel" => 36,
        "signal" => -55, "satisfaction" => 98, "ap_mac" => "D0:21:F9:8B:6A:ED", "network" => "Default", "vlan" => 1
      } ],
      networks: [ { "_id" => "net-1", "name" => "Default", "vlan" => 1 } ]
    ))

    assert result.complete?
    record = result.records.sole
    assert_equal "3c:22:fb:11:22:33", record.ieee_address
    assert_equal "client-1", record.client_external_id
    assert_equal "Romkey laptop", record.name
    assert_equal "romkey-laptop", record.hostname
    assert_equal "Loaner", record.note
    assert_equal "Apple, Inc.", record.manufacturer
    assert_equal "192.168.1.50", record.reserved_ip_address
    assert_equal "wireless", record.connection_type
    assert_equal "Hackerspace", record.ssid
    assert_equal "5 GHz", record.radio
    assert_equal "Wi-Fi 6", record.wifi_standard
    assert_equal 36, record.channel
    assert_equal(-55, record.signal)
    assert_equal 98, record.satisfaction
    assert_equal "d0:21:f9:8b:6a:ed", record.uplink_ieee_address
    assert_equal "Default", record.network_name
    assert_equal 1, record.vlan
    assert record.online
    assert_equal Time.zone.parse("2026-10-14T08:00:00Z"), record.connected_at
    assert_equal Time.zone.at(1_700_000_000), record.first_seen_at
  end

  test "keeps offline hosts the console still knows" do
    result = inventory(full_responses(
      known: [ { "mac" => "aa:bb:cc:dd:ee:10", "hostname" => "printer", "last_ip" => "192.168.1.60", "is_wired" => true } ]
    ))

    record = result.records.sole
    assert_not record.online
    assert_equal "wired", record.connection_type
    assert_equal "192.168.1.60", record.ip_address
    assert_nil record.reserved_ip_address
  end

  test "ignores a reservation that is switched off" do
    result = inventory(full_responses(
      known: [ { "mac" => "aa:bb:cc:dd:ee:10", "use_fixedip" => false, "fixed_ip" => "192.168.1.60" } ]
    ))

    assert_nil result.records.sole.reserved_ip_address
  end

  test "reads the switch port for a wired host" do
    result = inventory(full_responses(
      active: [ { "mac" => "aa:bb:cc:dd:ee:10", "is_wired" => true, "sw_mac" => "94:2a:6f:26:c6:ca", "sw_port" => 7,
                  "essid" => "ignored" } ]
    ))

    record = result.records.sole
    assert_equal 7, record.switch_port
    assert_equal "94:2a:6f:26:c6:ca", record.uplink_ieee_address
    assert_nil record.ssid
  end

  test "falls back to connected clients when the console lists are refused" do
    result = inventory(
      SITES_PATH => [ 200, unifi_page([ SITE ]) ],
      CLIENTS_PATH => [ 200, unifi_page([ { "id" => "client-1", "type" => "WIRED", "macAddress" => "aa:bb:cc:dd:ee:10" } ]) ],
      KNOWN_PATH => [ 401, { "meta" => { "rc" => "error", "msg" => "api.err.LoginRequired" } } ]
    )

    assert_not result.complete?
    assert_match "only connected hosts were read", result.notes.sole
    assert_equal "wired", result.records.sole.connection_type
  end

  test "skips clients without a usable MAC address" do
    result = inventory(full_responses(connected: [ { "id" => "vpn-1", "type" => "VPN", "macAddress" => nil } ]))

    assert_empty result.records
  end
end
