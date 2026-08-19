require "test_helper"

class Settings::UnifiDevicesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:local_admin))
    @unifi_device = unifi_devices(:rack_switch)
  end

  test "requires signing in" do
    delete logout_path

    patch settings_unifi_device_path(@unifi_device, ignored: "1")
    assert_redirected_to login_path
  end

  test "ignoring a device unlinks its thing" do
    thing = @unifi_device.thing

    patch settings_unifi_device_path(@unifi_device, ignored: "1")

    @unifi_device.reload
    assert @unifi_device.ignored?
    assert_nil @unifi_device.thing
    assert Thing.exists?(thing.id), "ignoring must not delete the thing"
    assert_redirected_to settings_unifi_controller_path(@unifi_device.unifi_controller)
  end

  test "unignoring a device relinks it by MAC address" do
    thing = @unifi_device.thing
    @unifi_device.update!(ignored: true, thing: nil)

    patch settings_unifi_device_path(@unifi_device, ignored: "0")

    @unifi_device.reload
    assert_not @unifi_device.ignored?
    assert_equal thing, @unifi_device.thing
  end
end
