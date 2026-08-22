require "test_helper"

class Zigbee2mqtt::TestConnectionTest < ActiveSupport::TestCase
  test "reports success when devices payload is available" do
    bridge = zigbee2mqtt_bridges(:workshop)
    client = Zigbee2mqtt::Client.new(
      bridge: bridge,
      transport: zigbee2mqtt_transport(devices: [ { "ieee_address" => "0x90fd9ffffe6494fc" } ])
    )

    result = Zigbee2mqtt::TestConnection.call(zigbee2mqtt_bridge: bridge, client: client)

    assert result.success?
    assert_match(/1 device/, result.message)
  end
end
