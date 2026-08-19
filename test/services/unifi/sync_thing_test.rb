require "test_helper"

class Unifi::SyncThingTest < ActiveSupport::TestCase
  def build_device(attributes = {})
    unifi_controllers(:udm).unifi_devices.create!({
      source: "network",
      external_id: SecureRandom.uuid,
      kind: "access_point",
      name: "Loft AP",
      model: "U6-Lite",
      mac_address: "aa:bb:cc:dd:ee:01",
      ip_address: "192.168.1.20",
      state: "ONLINE",
      first_seen_at: Time.current,
      last_seen_at: Time.current
    }.merge(attributes))
  end

  test "creates a thing from a device" do
    device = build_device

    assert_difference -> { Thing.count }, 1 do
      assert_equal :created, Unifi::SyncThing.call(unifi_device: device)
    end

    thing = device.reload.thing
    assert_equal "Loft AP", thing.name
    assert_equal "192.168.1.20", thing.ip_address
    assert_equal "aa:bb:cc:dd:ee:01", thing.mac_address
  end

  test "names a thing after its kind and MAC when the device is unnamed" do
    device = build_device(name: nil)

    Unifi::SyncThing.call(unifi_device: device)

    assert_equal "Access point aa:bb:cc:dd:ee:01", device.reload.thing.name
  end

  test "links to an existing thing with the same MAC instead of creating one" do
    existing = Thing.create!(name: "Loft AP (manual)", mac_address: "aa:bb:cc:dd:ee:01")
    device = build_device

    assert_no_difference -> { Thing.count } do
      assert_equal :linked, Unifi::SyncThing.call(unifi_device: device)
    end

    assert_equal existing, device.reload.thing
  end

  test "matches devices from both applications to one thing" do
    network_device = build_device(source: "network", kind: "gateway")
    protect_device = build_device(source: "protect", kind: "nvr", ip_address: nil)

    Unifi::SyncThing.call(unifi_device: network_device)
    Unifi::SyncThing.call(unifi_device: protect_device)

    assert_equal network_device.reload.thing, protect_device.reload.thing
  end

  test "refreshes fields the import owns" do
    device = build_device
    Unifi::SyncThing.call(unifi_device: device)

    device.update!(name: "Loft AP 2", ip_address: "192.168.1.21")
    assert_equal :updated, Unifi::SyncThing.call(unifi_device: device)

    thing = device.reload.thing
    assert_equal "Loft AP 2", thing.name
    assert_equal "192.168.1.21", thing.ip_address
  end

  test "never overwrites a field edited by hand" do
    device = build_device
    Unifi::SyncThing.call(unifi_device: device)
    device.thing.update!(name: "Loft access point (east)")

    device.update!(name: "Loft AP renamed in UniFi", ip_address: "192.168.1.21")
    Unifi::SyncThing.call(unifi_device: device)

    thing = device.reload.thing
    assert_equal "Loft access point (east)", thing.name
    assert_equal "192.168.1.21", thing.ip_address, "untouched fields should still sync"
  end

  test "fills in a field the user cleared only when it is blank" do
    device = build_device
    Unifi::SyncThing.call(unifi_device: device)
    device.thing.update!(ip_address: "")

    Unifi::SyncThing.call(unifi_device: device)

    assert_equal "192.168.1.20", device.reload.thing.ip_address
  end

  test "skips unlinked devices when the controller does not create things" do
    device = build_device

    assert_no_difference -> { Thing.count } do
      assert_equal :skipped, Unifi::SyncThing.call(unifi_device: device, auto_create: false)
    end

    assert_nil device.reload.thing
  end

  test "still updates an already linked thing when auto create is off" do
    device = build_device
    Unifi::SyncThing.call(unifi_device: device)
    device.update!(name: "Renamed")

    assert_equal :updated, Unifi::SyncThing.call(unifi_device: device, auto_create: false)
    assert_equal "Renamed", device.reload.thing.name
  end

  test "does nothing for an ignored device" do
    device = build_device(ignored: true)

    assert_no_difference -> { Thing.count } do
      assert_equal :ignored, Unifi::SyncThing.call(unifi_device: device)
    end
  end
end
