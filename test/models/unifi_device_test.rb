require "test_helper"

class UnifiDeviceTest < ActiveSupport::TestCase
  test "requires an external id unique per controller and application" do
    duplicate = unifi_controllers(:udm).unifi_devices.build(
      source: "network",
      external_id: unifi_devices(:rack_switch).external_id,
      kind: "switch",
      first_seen_at: Time.current,
      last_seen_at: Time.current
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:external_id], "has already been taken"
  end

  test "allows the same external id in the other application" do
    device = unifi_controllers(:udm).unifi_devices.build(
      source: "protect",
      external_id: unifi_devices(:rack_switch).external_id,
      kind: "nvr",
      first_seen_at: Time.current,
      last_seen_at: Time.current
    )

    assert device.valid?
  end

  test "labels kinds and applications for display" do
    assert_equal "Switch", unifi_devices(:rack_switch).kind_label
    assert_equal "Network", unifi_devices(:rack_switch).source_label
    assert_equal "Camera", unifi_devices(:front_door_camera).kind_label
    assert_equal "Protect", unifi_devices(:front_door_camera).source_label
  end

  test "treats both applications' connected states as online" do
    assert_predicate unifi_devices(:rack_switch), :online?
    assert_predicate unifi_devices(:front_door_camera), :online?
    assert_not_predicate unifi_devices(:retired_access_point), :online?
  end

  test "separates active and archived devices" do
    assert_includes UnifiDevice.active, unifi_devices(:rack_switch)
    assert_includes UnifiDevice.archived, unifi_devices(:retired_access_point)
    assert_not_includes UnifiDevice.active, unifi_devices(:retired_access_point)
  end

  test "falls back to the kind and id for a device with no name" do
    device = unifi_devices(:rack_switch)
    device.update!(name: nil, model: nil)

    assert_equal "Switch #{device.external_id}", device.display_name
  end
end
