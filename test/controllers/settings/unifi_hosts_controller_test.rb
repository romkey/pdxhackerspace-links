require "test_helper"

class Settings::UnifiHostsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:local_admin))
    @unifi_controller = unifi_controllers(:udm)
  end

  test "requires signing in" do
    delete logout_path

    get settings_unifi_controller_unifi_hosts_path(@unifi_controller)
    assert_redirected_to login_path
  end

  test "lists hosts with their reservations and things" do
    get settings_unifi_controller_unifi_hosts_path(@unifi_controller)

    assert_response :success
    assert_match "romkey-laptop", response.body
    assert_match "Hackerspace", response.body
    assert_select "a[href=?]", thing_path(things(:router)), text: "Router"
  end

  test "filters and searches hosts" do
    get settings_unifi_controller_unifi_hosts_path(@unifi_controller, filter: "reserved")
    assert_match "Router", response.body
    assert_no_match "romkey-laptop", response.body

    get settings_unifi_controller_unifi_hosts_path(@unifi_controller, q: "3c:22")
    assert_match "romkey-laptop", response.body
    assert_no_match "Ubiquiti", response.body
  end

  test "hides archived hosts unless asked" do
    unifi_hosts(:laptop_host).update!(archived_at: Time.current)

    get settings_unifi_controller_unifi_hosts_path(@unifi_controller)
    assert_no_match "romkey-laptop", response.body

    get settings_unifi_controller_unifi_hosts_path(@unifi_controller, archived: "1")
    assert_match "romkey-laptop", response.body
  end

  test "ignoring a host unlinks its thing" do
    host = unifi_hosts(:router_host)

    patch settings_unifi_host_path(host, ignored: "1")

    host.reload
    assert host.ignored?
    assert_nil host.thing
    assert_empty host.applied_attributes
    assert Thing.exists?(things(:router).id)
  end

  test "unignoring a host links it again" do
    host = unifi_hosts(:router_host)
    host.update!(ignored: true, thing: nil)

    patch settings_unifi_host_path(host, ignored: "0")

    assert_equal things(:router), host.reload.thing
  end

  test "the controller page links to its hosts" do
    get settings_unifi_controller_path(@unifi_controller)

    assert_select "a[href=?]", settings_unifi_controller_unifi_hosts_path(@unifi_controller), text: /2 known, 1 linked/
  end

  test "unlinked hosts offer to add or link a thing" do
    get settings_unifi_controller_unifi_hosts_path(@unifi_controller)

    host = unifi_hosts(:laptop_host)
    assert_select "form[action=?]", add_thing_settings_unifi_host_path(host), count: 2
    assert_select "[data-thing-picker-select-url-template-value=?]", link_settings_unifi_host_path(host, thing_id: "__SOURCE__")
    assert_select "form[action=?]", add_thing_settings_unifi_host_path(unifi_hosts(:router_host)), count: 0
  end

  test "adding a thing creates it from the host and links it" do
    host = unifi_hosts(:laptop_host)

    assert_difference -> { Thing.count }, 1 do
      post add_thing_settings_unifi_host_path(host)
    end

    thing = host.reload.thing
    assert_equal "romkey-laptop", thing.name
    assert_equal "romkey-laptop", thing.hostname
    assert_equal "3c:22:fb:11:22:33", thing.ieee_address
    assert_equal "192.168.1.50", thing.ip_address
    assert_equal "Apple, Inc.", thing.manufacturer
    assert_equal "Default", thing.network_name
    assert_redirected_to settings_unifi_controller_unifi_hosts_path(@unifi_controller)
  end

  test "adding a thing drops a hostname things would reject" do
    host = unifi_hosts(:laptop_host)
    host.update!(hostname: "Romkey's Laptop")

    post add_thing_settings_unifi_host_path(host)

    thing = host.reload.thing
    assert_equal "Romkey's Laptop", thing.name
    assert_nil thing.hostname
  end

  test "adding a thing reports why it could not" do
    host = unifi_hosts(:laptop_host)
    Thing.create!(name: "Other", ieee_address: host.ieee_address)

    assert_no_difference -> { Thing.count } do
      post add_thing_settings_unifi_host_path(host)
    end

    assert_nil host.reload.thing
    assert_match "Couldn't add", flash[:alert]
  end

  test "linking a host to a chosen thing" do
    host = unifi_hosts(:laptop_host)
    thing = things(:router)

    post link_settings_unifi_host_path(host, thing_id: thing.id)

    assert_equal thing, host.reload.thing
    assert_redirected_to settings_unifi_controller_unifi_hosts_path(@unifi_controller)
  end
end
