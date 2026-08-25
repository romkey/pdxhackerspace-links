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
end
