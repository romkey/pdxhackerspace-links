require "test_helper"

class UnifiHostTest < ActiveSupport::TestCase
  test "is unique per controller, site, and MAC address" do
    duplicate = unifi_hosts(:laptop_host).dup

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:ieee_address], "has already been taken"
  end

  test "rejects an unknown connection type" do
    host = unifi_hosts(:laptop_host)
    host.connection_type = "carrier pigeon"

    assert_not host.valid?
  end

  test "describes how it connects" do
    assert_equal "Wi-Fi", unifi_hosts(:laptop_host).connection_label
    assert_equal "Wired", unifi_hosts(:router_host).connection_label
    assert_equal "Rack switch port 1", unifi_hosts(:router_host).uplink_label
    assert_equal "-55 dBm", unifi_hosts(:laptop_host).signal_label
  end

  test "falls back from name to hostname to MAC address" do
    host = unifi_hosts(:laptop_host)
    assert_equal "romkey-laptop", host.display_name

    host.hostname = nil
    assert_equal "3c:22:fb:11:22:33", host.display_name
  end

  test "a deleted thing leaves its hosts unlinked but not ignored" do
    host = unifi_hosts(:router_host)
    host.thing.unifi_devices.destroy_all
    host.thing.destroy!

    host.reload
    assert_nil host.thing
    assert_not host.ignored?
  end
end
