require "test_helper"

class Settings::Zigbee2mqttDevicesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:local_admin))
    @device = zigbee2mqtt_devices(:bulb)
  end

  test "ignoring a device unlinks its thing" do
    thing = Thing.create!(name: "Linked bulb", ieee_address: @device.ieee_address)
    @device.update!(thing: thing)

    patch settings_zigbee2mqtt_device_path(@device, ignored: "1")

    @device.reload
    assert @device.ignored?
    assert_nil @device.thing
    assert Thing.exists?(thing.id)
  end

  test "unlinking a device does not ignore it" do
    thing = Thing.create!(name: "Linked bulb", ieee_address: @device.ieee_address)
    @device.update!(thing: thing)

    post unlink_settings_zigbee2mqtt_device_path(@device), headers: { "HTTP_REFERER" => thing_url(thing) }

    @device.reload
    assert_nil @device.thing
    assert_not @device.auto_link?
    assert_not @device.ignored?
    assert_equal :unlinked, Integrations::SyncThing.call(integration_device: @device)
    assert_redirected_to thing_path(thing)
  end

  test "linking an unlinked device attaches the matching thing" do
    thing = Thing.create!(name: "Linked bulb", ieee_address: @device.ieee_address)
    @device.update!(thing: thing, auto_link: false)
    Integrations::Unlink.call(@device)

    post link_settings_zigbee2mqtt_device_path(@device)

    assert_equal thing, @device.reload.thing
    assert @device.auto_link?
  end
end
