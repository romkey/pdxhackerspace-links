require "test_helper"

class Settings::UnifiControllersControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:local_admin))
  end

  test "requires signing in" do
    delete logout_path

    get settings_unifi_controllers_path
    assert_redirected_to login_path
  end

  test "index lists controllers" do
    get settings_unifi_controllers_path

    assert_response :success
    assert_select "td", text: unifi_controllers(:udm).name
  end

  test "settings navigation links to UniFi" do
    get settings_printers_path

    assert_select "a[href=?]", settings_unifi_controllers_path, text: "UniFi"
  end

  test "show lists imported devices and their things" do
    get settings_unifi_controller_path(unifi_controllers(:udm))

    assert_response :success
    assert_select "td", text: /Front door camera/
    assert_select "a[href=?]", thing_path(things(:router))
  end

  test "show hides archived devices until asked" do
    get settings_unifi_controller_path(unifi_controllers(:udm))
    assert_select "td", { text: /Loft AP/, count: 0 }

    get settings_unifi_controller_path(unifi_controllers(:udm), archived: "1")
    assert_select "td", text: /Loft AP/
  end

  test "creates a controller" do
    assert_difference -> { UnifiController.count }, 1 do
      post settings_unifi_controllers_path, params: {
        unifi_controller: {
          name: "Loft console",
          host: "https://192.168.9.1",
          port: 443,
          api_key: "a-new-key",
          network_enabled: "1",
          protect_enabled: "1",
          auto_create_things: "1",
          enabled: "1"
        }
      }
    end

    unifi_controller = UnifiController.find_by(name: "Loft console")
    assert_redirected_to settings_unifi_controller_path(unifi_controller)
    assert_equal "192.168.9.1", unifi_controller.host
    assert_equal "a-new-key", unifi_controller.api_key
  end

  test "rejects a controller with no applications enabled" do
    assert_no_difference -> { UnifiController.count } do
      post settings_unifi_controllers_path, params: {
        unifi_controller: {
          name: "Empty", host: "10.9.9.9", api_key: "key",
          network_enabled: "0", protect_enabled: "0"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "updating without an API key keeps the saved one" do
    unifi_controller = unifi_controllers(:udm)

    patch settings_unifi_controller_path(unifi_controller), params: {
      unifi_controller: { name: "Renamed console", api_key: "" }
    }

    unifi_controller.reload
    assert_equal "Renamed console", unifi_controller.name
    assert_equal "network-and-protect-key", unifi_controller.api_key
  end

  test "updating with an API key replaces it" do
    unifi_controller = unifi_controllers(:udm)

    patch settings_unifi_controller_path(unifi_controller), params: {
      unifi_controller: { api_key: "rotated-key" }
    }

    assert_equal "rotated-key", unifi_controller.reload.api_key
  end

  test "the form never renders the saved API key" do
    get edit_settings_unifi_controller_path(unifi_controllers(:udm))

    assert_response :success
    assert_select "input[name=?][value=?]", "unifi_controller[api_key]", "network-and-protect-key", count: 0
  end

  test "deletes a controller" do
    assert_difference -> { UnifiController.count }, -1 do
      delete settings_unifi_controller_path(unifi_controllers(:retired))
    end

    assert_redirected_to settings_unifi_controllers_path
  end

  test "test connection reports the reachable applications" do
    unifi_controller = unifi_controllers(:udm)
    result = Unifi::TestConnection::Result.new(versions: { "Network" => "9.3.45" }, errors: [])

    stubbing(Unifi::TestConnection, :call, ->(**) { result }) do
      post test_connection_settings_unifi_controller_path(unifi_controller)
    end

    assert_redirected_to settings_unifi_controller_path(unifi_controller)
    assert_match "Connected to Network 9.3.45", flash[:notice]
  end

  test "test connection reports a failure as an alert" do
    unifi_controller = unifi_controllers(:udm)
    result = Unifi::TestConnection::Result.new(versions: {}, errors: [ "Network: Timed out" ])

    stubbing(Unifi::TestConnection, :call, ->(**) { result }) do
      post test_connection_settings_unifi_controller_path(unifi_controller)
    end

    assert_match "Timed out", flash[:alert]
  end

  test "import queues a background job" do
    unifi_controller = unifi_controllers(:udm)

    assert_enqueued_with(job: Unifi::ImportJob, args: [ unifi_controller.id ]) do
      post import_settings_unifi_controller_path(unifi_controller)
    end

    assert_redirected_to settings_unifi_controller_path(unifi_controller)
    assert_predicate unifi_controller.reload, :syncing?
  end
end
