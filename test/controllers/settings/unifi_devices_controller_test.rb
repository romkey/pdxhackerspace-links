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

  test "unlinking a device keeps the thing and stops the next import from linking it" do
    thing = @unifi_device.thing

    post unlink_settings_unifi_device_path(@unifi_device), headers: { "HTTP_REFERER" => thing_url(thing) }

    @unifi_device.reload
    assert_not @unifi_device.ignored?
    assert_not @unifi_device.auto_link?
    assert_nil @unifi_device.thing
    assert_equal "Router", thing.reload.name
    assert_redirected_to thing_path(thing)
    assert_equal "#{@unifi_device.display_name} is no longer linked to #{thing.name}.", flash[:notice]

    assert_equal :unlinked, Unifi::SyncThing.call(unifi_device: @unifi_device)
    assert_nil @unifi_device.reload.thing
  end

  test "linking an unlinked device attaches it again" do
    thing = @unifi_device.thing
    Integrations::Unlink.call(@unifi_device)

    post link_settings_unifi_device_path(@unifi_device)

    @unifi_device.reload
    assert @unifi_device.auto_link?
    assert_not @unifi_device.ignored?
    assert_equal thing, @unifi_device.thing
    assert_redirected_to settings_unifi_controller_path(@unifi_device.unifi_controller)
  end

  test "the controller page offers to unlink a linked device" do
    get settings_unifi_controller_path(@unifi_device.unifi_controller)

    assert_select "form[action=?]", unlink_settings_unifi_device_path(@unifi_device)
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
