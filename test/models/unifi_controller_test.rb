require "test_helper"

class UnifiControllerTest < ActiveSupport::TestCase
  test "requires a name, host, and API key" do
    unifi_controller = UnifiController.new

    assert_not unifi_controller.valid?
    assert_includes unifi_controller.errors[:name], "can't be blank"
    assert_includes unifi_controller.errors[:host], "can't be blank"
    assert_includes unifi_controller.errors[:api_key], "can't be blank"
  end

  test "strips a scheme, port, and path from the host" do
    unifi_controller = UnifiController.new(host: "HTTPS://UniFi.example.com:8443/network/default")

    unifi_controller.valid?

    assert_equal "unifi.example.com", unifi_controller.host
  end

  test "rejects a host that is not a hostname or address" do
    unifi_controller = UnifiController.new(name: "Bad", host: "not a host", api_key: "key")

    assert_not unifi_controller.valid?
    assert_includes unifi_controller.errors[:host], "is invalid"
  end

  test "requires a unique host and port pair" do
    duplicate = UnifiController.new(name: "Copy", host: "unifi.example.com", port: 443, api_key: "key")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:host], "has already been taken"
  end

  test "allows the same host on a different port" do
    unifi_controller = UnifiController.new(name: "Alt port", host: "unifi.example.com", port: 8443, api_key: "key")

    assert unifi_controller.valid?
  end

  test "requires at least one application" do
    unifi_controller = UnifiController.new(
      name: "Nothing", host: "10.0.0.1", api_key: "key",
      network_enabled: false, protect_enabled: false
    )

    assert_not unifi_controller.valid?
    assert_includes unifi_controller.errors[:base], "Enable the Network API, the Protect API, or both"
  end

  test "rejects a port outside the valid range" do
    unifi_controller = UnifiController.new(name: "Bad port", host: "10.0.0.1", api_key: "key", port: 70_000)

    assert_not unifi_controller.valid?
    assert_includes unifi_controller.errors[:port], "must be less than or equal to 65535"
  end

  test "stores the API key encrypted" do
    unifi_controller = UnifiController.create!(name: "Encrypted", host: "10.0.0.9", api_key: "plaintext-key")
    at_rest = UnifiController.connection.select_value(
      UnifiController.sanitize_sql([ "SELECT api_key FROM unifi_controllers WHERE id = ?", unifi_controller.id ])
    )

    assert_equal "plaintext-key", unifi_controller.reload.api_key
    assert_not_includes at_rest, "plaintext-key"
  end

  test "omits the default port from the base URL" do
    assert_equal "https://unifi.example.com", unifi_controllers(:udm).base_url
    assert_equal "https://old.example.com:8443", unifi_controllers(:retired).base_url
  end

  test "lists the enabled applications" do
    assert_equal %w[network protect], unifi_controllers(:udm).enabled_applications
    assert_equal %w[network], unifi_controllers(:network_only).enabled_applications
  end

  test "counts only devices that are still present" do
    assert_equal 2, unifi_controllers(:udm).device_count
  end

  test "reports the sync state behind the last status" do
    unifi_controller = unifi_controllers(:udm)

    unifi_controller.last_sync_status = "skipped"
    assert unifi_controller.valid?
    assert_predicate unifi_controller, :last_sync_skipped?
    assert_not_predicate unifi_controller, :syncing?

    unifi_controller.last_sync_status = "elsewhere"
    assert_not unifi_controller.valid?
  end

  test "shares one rate limiter across both application clients" do
    unifi_controller = unifi_controllers(:udm)

    assert_same unifi_controller.rate_limiter, unifi_controller.rate_limiter
  end

  test "deleting a controller removes its devices but keeps their things" do
    unifi_controller = unifi_controllers(:udm)
    thing = unifi_devices(:rack_switch).thing

    assert_difference -> { UnifiDevice.count }, -3 do
      assert_no_difference -> { Thing.count } do
        unifi_controller.destroy!
      end
    end

    assert Thing.exists?(thing.id)
  end
end
