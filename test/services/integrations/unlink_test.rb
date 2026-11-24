require "test_helper"

class Integrations::UnlinkTest < ActiveSupport::TestCase
  setup do
    Current.user = users(:local_admin)
  end

  teardown do
    Current.user = nil
  end

  test "detaches the thing and stops automatic linking" do
    device = unifi_devices(:rack_switch)
    thing = device.thing
    name = thing.name
    ieee_address = thing.ieee_address

    Integrations::Unlink.call(device)

    device.reload
    thing.reload
    assert_nil device.thing
    assert_not device.auto_link?
    assert_not device.ignored?
    assert_equal name, thing.name
    assert_equal ieee_address, thing.ieee_address
    assert_equal "unifi", thing.integration_source
    assert_equal "unlinked", thing.journal_entries.order(:id).last.event
    assert_equal "UniFi · Router", thing.journal_entries.order(:id).last.message
    assert_equal users(:local_admin), thing.journal_entries.order(:id).last.user
  end

  test "moves the thing's last-changed time" do
    device = unifi_devices(:rack_switch)
    thing = device.thing
    thing.update_column(:updated_at, 2.days.ago)

    Integrations::Unlink.call(device)

    assert_in_delta Time.current, thing.reload.updated_at, 5
  end

  test "does nothing when the record is already unlinked" do
    host = unifi_hosts(:laptop_host)

    assert_no_difference -> { JournalEntry.count } do
      Integrations::Unlink.call(host)
    end

    assert host.reload.auto_link?
    assert_nil host.thing
  end

  test "names a host separately from a UniFi device" do
    Integrations::Unlink.call(unifi_hosts(:router_host))

    entry = things(:router).journal_entries.order(:id).last
    assert_equal "UniFi host · Router", entry.message
  end
end
