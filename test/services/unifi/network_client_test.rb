require "test_helper"

class Unifi::NetworkClientTest < ActiveSupport::TestCase
  SITE = { "id" => "site-1", "internalReference" => "default", "name" => "Default" }.freeze

  def build_client(responses)
    Unifi::NetworkClient.for(unifi_controllers(:udm), transport: unifi_transport(responses))
  end

  def device(overrides = {})
    {
      "id" => "device-1",
      "name" => "Rack switch",
      "model" => "USW-24-PoE",
      "macAddress" => "94:2A:6F:26:C6:CA",
      "ipAddress" => "192.168.1.5",
      "state" => "ONLINE",
      "firmwareVersion" => "6.6.55",
      "firmwareUpdatable" => false,
      "supported" => true,
      "features" => [ "switching" ],
      "interfaces" => [ "ports" ]
    }.merge(overrides)
  end

  test "reads the application version" do
    client = build_client("/proxy/network/integration/v1/info" => [ 200, { "applicationVersion" => "9.3.45" } ])

    assert_equal "9.3.45", client.application_version
  end

  test "builds device records for every site" do
    client = build_client(
      "/proxy/network/integration/v1/sites?limit=200&offset=0" => [ 200, unifi_page([ SITE ]) ],
      "/proxy/network/integration/v1/sites/site-1/devices?limit=200&offset=0" => [ 200, unifi_page([ device ]) ]
    )

    record = client.device_records.sole

    assert_equal "network", record.source
    assert_equal "device-1", record.external_id
    assert_equal "switch", record.kind
    assert_equal "Rack switch", record.name
    assert_equal "USW-24-PoE", record.model
    assert_equal "192.168.1.5", record.ip_address
    assert_equal "6.6.55", record.firmware_version
    assert_equal "ONLINE", record.state
    assert_equal "site-1", record.site_external_id
    assert_equal "Default", record.site_name
  end

  test "normalizes MAC addresses to lowercase colon form" do
    client = build_client(
      "/proxy/network/integration/v1/sites?limit=200&offset=0" => [ 200, unifi_page([ SITE ]) ],
      "/proxy/network/integration/v1/sites/site-1/devices?limit=200&offset=0" => [ 200, unifi_page([ device ]) ]
    )

    assert_equal "94:2a:6f:26:c6:ca", client.device_records.sole.ieee_address
  end

  test "maps the most specific role to a kind" do
    kinds = {
      [ "gateway", "switching", "accessPoint" ] => "gateway",
      [ "switching" ] => "switch",
      [ "accessPoint" ] => "access_point",
      [] => "device"
    }

    kinds.each do |features, expected|
      client = build_client(
        "/proxy/network/integration/v1/sites?limit=200&offset=0" => [ 200, unifi_page([ SITE ]) ],
        "/proxy/network/integration/v1/sites/site-1/devices?limit=200&offset=0" =>
          [ 200, unifi_page([ device("features" => features) ]) ]
      )

      assert_equal expected, client.device_records.sole.kind, "features #{features.inspect}"
    end
  end

  test "follows pagination until every device is read" do
    first = { "offset" => 0, "limit" => 200, "count" => 1, "totalCount" => 2, "data" => [ device("id" => "a") ] }
    second = { "offset" => 1, "limit" => 200, "count" => 1, "totalCount" => 2, "data" => [ device("id" => "b") ] }

    client = build_client(
      "/proxy/network/integration/v1/sites?limit=200&offset=0" => [ 200, unifi_page([ SITE ]) ],
      "/proxy/network/integration/v1/sites/site-1/devices?limit=200&offset=0" => [ 200, first ],
      "/proxy/network/integration/v1/sites/site-1/devices?limit=200&offset=1" => [ 200, second ]
    )

    assert_equal %w[a b], client.device_records.map(&:external_id)
  end
end
