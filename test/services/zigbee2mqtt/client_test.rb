require "test_helper"

class Zigbee2mqtt::ClientTest < ActiveSupport::TestCase
  setup do
    @bridge = zigbee2mqtt_bridges(:workshop)
  end

  def sample_device(overrides = {})
    {
      "ieee_address" => "0x90fd9ffffe6494fc",
      "friendly_name" => "workshop_bulb",
      "type" => "Router",
      "supported" => true,
      "disabled" => false,
      "definition" => {
        "vendor" => "IKEA",
        "model" => "LED1624G9",
        "description" => "TRADFRI bulb"
      }
    }.merge(overrides)
  end

  test "builds device records from bridge devices payload" do
    client = Zigbee2mqtt::Client.new(
      bridge: @bridge,
      transport: zigbee2mqtt_transport(devices: [ sample_device ])
    )

    record = client.device_records.sole
    assert_equal "90:fd:9f:ff:fe:64:94:fc", record.ieee_address
    assert_equal "IKEA", record.manufacturer
    assert_equal "LED1624G9", record.model
  end

  test "maps last_seen timestamps onto device records" do
    seen_at = 2.hours.ago.change(usec: 0)
    client = Zigbee2mqtt::Client.new(
      bridge: @bridge,
      transport: zigbee2mqtt_transport(
        devices: [ sample_device ],
        last_seen: { "90:fd:9f:ff:fe:64:94:fc" => seen_at }
      )
    )

    assert_equal seen_at, client.device_records.sole.reported_last_seen_at
  end
end
