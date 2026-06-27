require "test_helper"

class NetworkGuestAccessTest < ActionDispatch::IntegrationTest
  setup do
    delete logout_path
  end

  test "requires authentication when whitelist is not configured" do
    with_network_whitelist(nil) do
      get things_path
      assert_redirected_to login_path
      assert_equal "Please sign in to continue.", flash[:alert]
    end
  end

  test "requires authentication from non-whitelisted network" do
    with_network_whitelist("192.168.0.0/16") do
      get things_path, env: from_network("10.0.0.1")
      assert_redirected_to login_path
    end
  end

  test "allows browsing things from whitelisted network" do
    with_network_whitelist("192.168.0.0/16") do
      get things_path, env: from_network("192.168.1.50")
      assert_response :success
      assert_select "td", text: things(:keyboard).name
      assert_select "a[href=?]", new_thing_path, count: 0
      assert_select "a[href=?]", login_path
    end
  end

  test "allows root path from whitelisted network" do
    with_network_whitelist("192.168.0.0/16") do
      get root_path, env: from_network("192.168.1.50")
      assert_response :success
      assert_select "h1", "Things"
    end
  end

  test "allows searching things from whitelisted network" do
    with_network_whitelist("192.168.0.0/16") do
      get things_path, params: { q: "keyboard" }, env: from_network("192.168.1.50")
      assert_response :success
      assert_select "td", text: things(:keyboard).name
      assert_select "td", text: things(:router).name, count: 0
      assert_select "nav input[type=search][name=q][value=?]", "keyboard"
    end
  end

  test "guest index hides management controls" do
    with_network_whitelist("192.168.0.0/16") do
      get things_path, env: from_network("192.168.1.50")

      assert_response :success
      assert_select "a[href=?]", settings_root_path, count: 0
      assert_select "a[href=?]", new_thing_path, count: 0
      assert_select "a[href=?]", edit_thing_path(things(:keyboard)), count: 0
      assert_select "button", text: "Duplicate", count: 0
      assert_select "button", text: "Delete", count: 0
      assert_select "button", text: "Print", count: 0
    end
  end

  test "allows viewing thing details from whitelisted network" do
    with_network_whitelist("192.168.0.0/16") do
      get thing_path(things(:keyboard)), env: from_network("192.168.1.50")
      assert_response :success
      assert_select "h1", things(:keyboard).name
      assert_select "a[href=?]", thing_links(:keyboard_wiki).url
      assert_select "a[href=?]", edit_thing_path(things(:keyboard)), count: 0
      assert_select "a[href*=?]", "label_preview", count: 0
      assert_select "button", text: /Print/, count: 0
    end
  end

  test "guest can still reach login page" do
    with_network_whitelist("192.168.0.0/16") do
      get login_path, env: from_network("192.168.1.50")
      assert_response :success
    end
  end

  test "signed in user keeps full access from whitelisted network" do
    with_network_whitelist("192.168.0.0/16") do
      sign_in_as(users(:local_admin))

      get things_path, env: from_network("192.168.1.50")
      assert_response :success
      assert_select "a[href=?]", new_thing_path
      assert_select "a[href=?]", settings_root_path
      assert_select "button", text: "Duplicate", minimum: 1

      get thing_path(things(:keyboard)), env: from_network("192.168.1.50")
      assert_response :success
      assert_select "a[href=?]", edit_thing_path(things(:keyboard))
      assert_select "a[href*=?]", "label_preview"
    end
  end

  test "blocks new thing form from whitelisted network" do
    with_network_whitelist("192.168.0.0/16") do
      get new_thing_path, env: from_network("192.168.1.50")
      assert_redirected_to root_path
      assert_equal "Sign in to do that.", flash[:alert]
    end
  end

  test "blocks create from whitelisted network" do
    with_network_whitelist("192.168.0.0/16") do
      assert_no_difference -> { Thing.count } do
        post things_path,
             params: { thing: { name: "Guest thing" } },
             env: from_network("192.168.1.50")
      end

      assert_redirected_to root_path
      assert_equal "Sign in to do that.", flash[:alert]
    end
  end

  test "blocks edit from whitelisted network" do
    with_network_whitelist("192.168.0.0/16") do
      get edit_thing_path(things(:router)), env: from_network("192.168.1.50")
      assert_redirected_to root_path
      assert_equal "Sign in to do that.", flash[:alert]
    end
  end

  test "blocks update from whitelisted network" do
    with_network_whitelist("192.168.0.0/16") do
      patch thing_path(things(:router)),
            params: { thing: { name: "Renamed by guest" } },
            env: from_network("192.168.1.50")

      assert_redirected_to root_path
      assert_equal "Sign in to do that.", flash[:alert]
      assert_equal things(:router).name, things(:router).reload.name
    end
  end

  test "blocks duplicate from whitelisted network" do
    with_network_whitelist("192.168.0.0/16") do
      assert_no_difference -> { Thing.count } do
        post duplicate_thing_path(things(:router)), env: from_network("192.168.1.50")
      end

      assert_redirected_to root_path
      assert_equal "Sign in to do that.", flash[:alert]
    end
  end

  test "blocks destroy from whitelisted network" do
    with_network_whitelist("192.168.0.0/16") do
      assert_no_difference -> { Thing.count } do
        delete thing_path(things(:router)), env: from_network("192.168.1.50")
      end

      assert_redirected_to root_path
      assert_equal "Sign in to do that.", flash[:alert]
    end
  end

  test "blocks purge photo from whitelisted network" do
    with_network_whitelist("192.168.0.0/16") do
      delete photo_thing_path(things(:keyboard), photo_id: 1), env: from_network("192.168.1.50")

      assert_redirected_to root_path
      assert_equal "Sign in to do that.", flash[:alert]
    end
  end

  test "blocks print from whitelisted network" do
    with_network_whitelist("192.168.0.0/16") do
      post print_thing_path(things(:keyboard)),
           params: { printer_id: printers(:brother_printer).id },
           env: from_network("192.168.1.50")

      assert_redirected_to root_path
      assert_equal "Sign in to do that.", flash[:alert]
    end
  end

  test "blocks label preview html from whitelisted network" do
    with_network_whitelist("192.168.0.0/16") do
      get label_preview_thing_path(things(:router), printer_id: printers(:label_printer).id),
          env: from_network("192.168.1.50")

      assert_redirected_to root_path
      assert_equal "Sign in to do that.", flash[:alert]
    end
  end

  test "blocks label preview pdf from whitelisted network" do
    with_network_whitelist("192.168.0.0/16") do
      get label_preview_thing_path(things(:router), printer_id: printers(:label_printer).id, format: :pdf),
          env: from_network("192.168.1.50")

      assert_redirected_to root_path
      assert_equal "Sign in to do that.", flash[:alert]
    end
  end

  test "blocks label preview png from whitelisted network" do
    with_network_whitelist("192.168.0.0/16") do
      get label_preview_thing_path(things(:router), printer_id: printers(:command_printer).id, format: :png),
          env: from_network("192.168.1.50")

      assert_redirected_to root_path
      assert_equal "Sign in to do that.", flash[:alert]
    end
  end

  test "blocks settings from whitelisted network" do
    with_network_whitelist("192.168.0.0/16") do
      get settings_root_path, env: from_network("192.168.1.50")
      assert_redirected_to login_path
      assert_equal "Please sign in to continue.", flash[:alert]
    end
  end

  test "blocks settings update from whitelisted network" do
    with_network_whitelist("192.168.0.0/16") do
      patch settings_site_path,
            params: { site_setting: { cups_server: "evil.example.com:631" } },
            env: from_network("192.168.1.50")

      assert_redirected_to login_path
      assert_not_equal "evil.example.com:631", SiteSetting.instance.cups_server
    end
  end

  test "blocks printer settings from whitelisted network" do
    with_network_whitelist("192.168.0.0/16") do
      get settings_printers_path, env: from_network("192.168.1.50")
      assert_redirected_to login_path
    end
  end

  test "uses client ip from x-forwarded-for through reverse proxy" do
    with_network_whitelist("192.168.0.0/16") do
      get things_path, env: through_proxy("10.0.0.1", client_ip: "192.168.1.50")
      assert_response :success
      assert_select "td", text: things(:keyboard).name
    end
  end

  test "does not grant whitelist access from spoofed x-forwarded-for" do
    with_network_whitelist("192.168.0.0/16") do
      get things_path, env: through_proxy("203.0.113.50", client_ip: "192.168.1.50")
      assert_redirected_to login_path
    end
  end

  test "guest can sign in from whitelisted network for full access" do
    with_network_whitelist("192.168.0.0/16") do
      get things_path, env: from_network("192.168.1.50")
      assert_response :success
      assert_select "a[href=?]", new_thing_path, count: 0

      sign_in_as(users(:local_admin))

      get things_path, env: from_network("192.168.1.50")
      assert_response :success
      assert_select "a[href=?]", new_thing_path
    end
  end

  test "exact ip whitelist entry grants access" do
    with_network_whitelist("192.168.1.50") do
      get things_path, env: from_network("192.168.1.50")
      assert_response :success

      get things_path, env: from_network("192.168.1.51")
      assert_redirected_to login_path
    end
  end
end
