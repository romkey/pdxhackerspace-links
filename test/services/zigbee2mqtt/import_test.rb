require "test_helper"

class Zigbee2mqtt::ImportTest < ActiveSupport::TestCase
  setup do
    @bridge = zigbee2mqtt_bridges(:workshop)
    @bridge.zigbee2mqtt_devices.destroy_all
  end

  def device_payload(overrides = {})
    {
      "ieee_address" => "0x90fd9ffffe6494fc",
      "friendly_name" => "workshop_bulb",
      "type" => "Router",
      "supported" => true,
      "disabled" => false,
      "definition" => { "vendor" => "IKEA", "model" => "LED1624G9" }
    }.merge(overrides)
  end

  def import(devices:, last_seen: {}, bridge: @bridge)
    client = Zigbee2mqtt::Client.new(
      bridge: bridge,
      transport: zigbee2mqtt_transport(devices: devices, last_seen: last_seen)
    )
    Zigbee2mqtt::Import.call(zigbee2mqtt_bridge: bridge, client: client)
  end

  test "creates devices and things from bridge payload" do
    result = import(devices: [ device_payload ])

    assert_equal "success", result.status
    assert_equal 1, result.devices_seen
    assert_equal 1, result.things_created

    device = @bridge.zigbee2mqtt_devices.sole
    thing = device.thing
    assert_equal "workshop_bulb", thing.name
    assert_equal "IKEA", thing.manufacturer
    assert_equal "LED1624G9", thing.model
    assert_equal "zigbee2mqtt", thing.integration_source
  end

  test "skips disabled devices when configured" do
    @bridge.update!(skip_disabled_devices: true)

    result = import(devices: [ device_payload("disabled" => true) ])

    assert_equal 0, result.devices_seen
    assert_equal 1, result.devices_skipped
  end

  test "skips devices outside the recency window" do
    @bridge.update!(last_seen_limit_days: 7, import_unknown_last_seen: false)

    result = import(
      devices: [ device_payload ],
      last_seen: { "90:fd:9f:ff:fe:64:94:fc" => 30.days.ago }
    )

    assert_equal 0, result.devices_seen
    assert_equal 1, result.devices_skipped
  end

  test "imports devices with unknown last_seen when enabled" do
    @bridge.update!(last_seen_limit_days: 7, import_unknown_last_seen: true)

    result = import(devices: [ device_payload ])

    assert_equal 1, result.devices_seen
  end

  test "skips devices with unknown last_seen when disabled" do
    @bridge.update!(last_seen_limit_days: 7, import_unknown_last_seen: false)

    result = import(devices: [ device_payload ])

    assert_equal 0, result.devices_seen
    assert_equal 1, result.devices_skipped
    assert_equal 1, result.skipped_unknown_last_seen
    assert_match(/advanced.last_seen/, result.summary)
  end

  test "does not archive devices when bridge payload is empty" do
    existing = @bridge.zigbee2mqtt_devices.create!(
      ieee_address: "90:fd:9f:ff:fe:64:94:fc",
      friendly_name: "existing_bulb",
      first_seen_at: 1.day.ago,
      last_seen_at: 1.hour.ago
    )

    result = import(devices: [])

    assert_equal 0, result.devices_archived
    assert_nil existing.reload.archived_at
  end

  test "does not archive skipped devices that remain on the bridge" do
    @bridge.update!(skip_disabled_devices: true)
    existing = @bridge.zigbee2mqtt_devices.create!(
      ieee_address: "90:fd:9f:ff:fe:64:94:fc",
      friendly_name: "disabled_bulb",
      disabled: true,
      first_seen_at: 1.day.ago,
      last_seen_at: 1.hour.ago
    )

    result = import(devices: [ device_payload("disabled" => true) ])

    assert_equal 0, result.devices_seen
    assert_equal 1, result.devices_skipped
    assert_equal 0, result.devices_archived
    assert_nil existing.reload.archived_at
  end

  test "archives devices missing from bridge payload" do
    stale = @bridge.zigbee2mqtt_devices.create!(
      ieee_address: "00:11:22:33:44:55:66:77",
      friendly_name: "stale_bulb",
      first_seen_at: 2.days.ago,
      last_seen_at: 1.day.ago
    )

    result = import(devices: [ device_payload ])

    assert_equal 1, result.devices_archived
    assert_not_nil stale.reload.archived_at
  end
end
