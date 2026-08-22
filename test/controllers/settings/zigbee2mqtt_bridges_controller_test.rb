require "test_helper"

class Settings::Zigbee2mqttBridgesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:local_admin))
    @bridge = zigbee2mqtt_bridges(:workshop)
  end

  test "index requires signing in" do
    delete logout_path
    get settings_zigbee2mqtt_bridges_path
    assert_redirected_to login_path
  end

  test "shows bridge details" do
    get settings_zigbee2mqtt_bridge_path(@bridge)
    assert_response :success
    assert_select "h1", text: @bridge.name
  end

  test "queues import" do
    assert_enqueued_with(job: Zigbee2mqtt::ImportJob) do
      post import_settings_zigbee2mqtt_bridge_path(@bridge)
    end

    assert_redirected_to settings_zigbee2mqtt_bridge_path(@bridge)
    assert_equal "running", @bridge.reload.last_sync_status
  end
end
