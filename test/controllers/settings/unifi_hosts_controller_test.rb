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
end
