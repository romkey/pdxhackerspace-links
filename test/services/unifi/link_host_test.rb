require "test_helper"

class Unifi::LinkHostTest < ActiveSupport::TestCase
  setup do
    @unifi_host = unifi_hosts(:laptop_host)
  end

  test "links to the thing with the same MAC address" do
    thing = Thing.create!(name: "Laptop", ieee_address: @unifi_host.ieee_address)

    assert_equal :linked, Unifi::LinkHost.call(unifi_host: @unifi_host)
    assert_equal thing, @unifi_host.reload.thing
  end

  test "links to the only thing with the same IP address" do
    thing = Thing.create!(name: "Laptop", ip_address: "192.168.1.50")

    Unifi::LinkHost.call(unifi_host: @unifi_host)

    assert_equal thing, @unifi_host.reload.thing
  end

  test "does not guess when several things share the IP address" do
    Thing.create!(name: "Laptop", ip_address: "192.168.1.50")
    Thing.create!(name: "Old laptop", ip_address: "192.168.1.50")

    assert_equal :unmatched, Unifi::LinkHost.call(unifi_host: @unifi_host)
    assert_nil @unifi_host.reload.thing
  end

  test "never creates a thing" do
    assert_no_difference -> { Thing.count } do
      assert_equal :unmatched, Unifi::LinkHost.call(unifi_host: @unifi_host)
    end
  end

  test "leaves an ignored host alone" do
    Thing.create!(name: "Laptop", ieee_address: @unifi_host.ieee_address)
    @unifi_host.update!(ignored: true)

    assert_equal :ignored, Unifi::LinkHost.call(unifi_host: @unifi_host)
    assert_nil @unifi_host.reload.thing
  end

  test "fills in the reserved IP address and nothing else" do
    thing = Thing.create!(name: "Laptop", ieee_address: @unifi_host.ieee_address)
    @unifi_host.update!(reserved_ip_address: "192.168.1.50")

    Unifi::LinkHost.call(unifi_host: @unifi_host)

    thing.reload
    assert_equal "192.168.1.50", thing.reserved_ip_address
    assert_nil thing.ip_address
    assert_nil thing.hostname
    assert_equal "Laptop", thing.name
  end

  test "follows a reservation change until it is edited by hand" do
    thing = Thing.create!(name: "Laptop", ieee_address: @unifi_host.ieee_address)
    @unifi_host.update!(reserved_ip_address: "192.168.1.50")
    Unifi::LinkHost.call(unifi_host: @unifi_host)

    @unifi_host.update!(reserved_ip_address: "192.168.1.51")
    Unifi::LinkHost.call(unifi_host: @unifi_host)
    assert_equal "192.168.1.51", thing.reload.reserved_ip_address

    thing.update!(reserved_ip_address: "10.0.0.5")
    @unifi_host.update!(reserved_ip_address: "192.168.1.52")
    Unifi::LinkHost.call(unifi_host: @unifi_host)
    assert_equal "10.0.0.5", thing.reload.reserved_ip_address
  end

  test "fills in the network name and keeps a hand edit" do
    thing = Thing.create!(name: "Laptop", ieee_address: @unifi_host.ieee_address)

    Unifi::LinkHost.call(unifi_host: @unifi_host)
    assert_equal "Default", thing.reload.network_name

    thing.update!(network_name: "Lab")
    @unifi_host.update!(network_name: "IoT")
    Unifi::LinkHost.call(unifi_host: @unifi_host)
    assert_equal "Lab", thing.reload.network_name
  end

  test "clears a reservation removed in UniFi" do
    thing = Thing.create!(name: "Laptop", ieee_address: @unifi_host.ieee_address)
    @unifi_host.update!(reserved_ip_address: "192.168.1.50")
    Unifi::LinkHost.call(unifi_host: @unifi_host)

    @unifi_host.update!(reserved_ip_address: nil)
    Unifi::LinkHost.call(unifi_host: @unifi_host)

    assert_nil thing.reload.reserved_ip_address
  end

  test "links a chosen thing whatever its addresses, unignoring the host" do
    thing = Thing.create!(name: "Work laptop")
    @unifi_host.update!(ignored: true)

    assert_equal :linked, Unifi::LinkHost.call(unifi_host: @unifi_host, thing: thing)

    @unifi_host.reload
    assert_equal thing, @unifi_host.thing
    assert_not @unifi_host.ignored?
    assert_equal "Default", thing.reload.network_name
  end

  test "relinking a chosen thing forgets values written to the previous one" do
    host = unifi_hosts(:router_host)
    host.update!(applied_attributes: { "reserved_ip_address" => "192.168.1.9" })
    thing = Thing.create!(name: "Gateway", reserved_ip_address: "192.168.1.9")

    Unifi::LinkHost.call(unifi_host: host, thing: thing)

    assert_equal thing, host.reload.thing
    assert_equal "192.168.1.9", thing.reload.reserved_ip_address
    assert_equal({ "network_name" => "Default" }, host.applied_attributes)
  end
end
