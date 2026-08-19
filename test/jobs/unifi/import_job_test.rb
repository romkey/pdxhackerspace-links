require "test_helper"

class Unifi::ImportJobTest < ActiveJob::TestCase
  test "imports the controller" do
    unifi_controller = unifi_controllers(:udm)
    called_with = nil

    stubbing(Unifi::Import, :call, ->(**kwargs) { called_with = kwargs[:unifi_controller] }) do
      Unifi::ImportJob.perform_now(unifi_controller.id)
    end

    assert_equal unifi_controller, called_with
  end

  test "does nothing for a disabled controller" do
    unifi_controller = unifi_controllers(:retired)

    stubbing(Unifi::Import, :call, ->(**) { flunk "disabled controllers must be skipped" }) do
      Unifi::ImportJob.perform_now(unifi_controller.id)
    end

    assert_nil unifi_controller.reload.last_synced_at
  end

  test "does nothing for a controller that has been deleted" do
    assert_nothing_raised { Unifi::ImportJob.perform_now(-1) }
  end

  test "records the failure on the controller before re-raising" do
    unifi_controller = unifi_controllers(:udm)

    stubbing(Unifi::Import, :call, ->(**) { raise Unifi::Client::ConnectionError, "Timed out" }) do
      assert_raises(Unifi::Client::ConnectionError) { Unifi::ImportJob.perform_now(unifi_controller.id) }
    end

    unifi_controller.reload
    assert_equal "failed", unifi_controller.last_sync_status
    assert_equal "Timed out", unifi_controller.last_sync_message
  end
end
