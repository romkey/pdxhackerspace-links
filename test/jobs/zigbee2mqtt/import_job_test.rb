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

  test "clears the queued marker when the bridge is disabled before the job runs" do
    bridge = zigbee2mqtt_bridges(:workshop)
    bridge.update!(enabled: false, last_sync_status: "running", last_sync_message: "Import queued.")

    stubbing(Zigbee2mqtt::Import, :call, ->(**) { flunk "disabled bridges must be skipped" }) do
      Zigbee2mqtt::ImportJob.perform_now(bridge.id)
    end

    bridge.reload
    assert_not_predicate bridge, :syncing?
    assert_equal "skipped", bridge.last_sync_status
    assert_match "disabled", bridge.last_sync_message
  end

  test "leaves an earlier result alone when skipping a disabled bridge" do
    bridge = zigbee2mqtt_bridges(:workshop)
    bridge.update!(
      enabled: false,
      last_synced_at: 2.days.ago,
      last_sync_status: "success",
      last_sync_message: "4 devices"
    )

    stubbing(Zigbee2mqtt::Import, :call, ->(**) { flunk "disabled bridges must be skipped" }) do
      Zigbee2mqtt::ImportJob.perform_now(bridge.id)
    end

    bridge.reload
    assert_equal "success", bridge.last_sync_status
    assert_equal "4 devices", bridge.last_sync_message
  end
end
