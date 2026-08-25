require "test_helper"

class Zigbee2mqtt::ImportJobTest < ActiveJob::TestCase
  test "imports from an enabled bridge" do
    bridge = zigbee2mqtt_bridges(:workshop)

    stubbing(Zigbee2mqtt::Import, :call, ->(**) { true }) do
      assert_nothing_raised do
        Zigbee2mqtt::ImportJob.perform_now(bridge.id)
      end
    end
  end

  test "skips disabled bridges" do
    bridge = zigbee2mqtt_bridges(:workshop)
    bridge.update!(enabled: false)

    called = false
    stubbing(Zigbee2mqtt::Import, :call, ->(**) { called = true }) do
      Zigbee2mqtt::ImportJob.perform_now(bridge.id)
    end

    assert_not called
  end
end
