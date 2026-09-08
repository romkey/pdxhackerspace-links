require "test_helper"

# Adding a field to an integration's desired_thing_attributes has to reach the
# things that already exist, not just the ones a later import creates. Serial
# number was the first field added after things were already in the database.
class IntegrationBackfillsNewThingFieldsTest < ActiveSupport::TestCase
  test "unifi import fills a serial number onto a thing it linked earlier" do
    device = unifi_devices(:rack_switch)
    thing = device.thing

    assert_nil thing.serial_number, "fixture should predate the serial number field"
    assert_not_includes device.applied_attributes.keys, "serial_number"

    device.update!(payload: { "serialNumber" => "FCECDA123456" })
    assert_equal :updated, Unifi::SyncThing.call(unifi_device: device)

    assert_equal "FCECDA123456", thing.reload.serial_number
    assert_equal "FCECDA123456", device.reload.applied_attributes["serial_number"]
  end

  test "zigbee2mqtt import fills a serial number onto a thing it linked earlier" do
    device = zigbee2mqtt_devices(:bulb)
    thing = Thing.create!(name: "Workshop bulb", ieee_address: device.ieee_address)
    device.update!(thing: thing, payload: { "serial" => "IKEA-77-1234" })

    assert_equal :updated, Integrations::SyncThing.call(integration_device: device)

    assert_equal "IKEA-77-1234", thing.reload.serial_number
  end

  test "a serial number entered by hand survives the next import" do
    device = unifi_devices(:rack_switch)
    device.thing.update!(serial_number: "TYPED-BY-HAND")

    device.update!(payload: { "serialNumber" => "FCECDA123456" })
    Unifi::SyncThing.call(unifi_device: device)

    assert_equal "TYPED-BY-HAND", device.thing.reload.serial_number
  end
end
