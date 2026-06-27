require "test_helper"

class Settings::SiteControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:local_admin))
    SiteSetting.instance.update!(cups_server: "cups.example.com:631")
  end

  test "show displays settings form" do
    get settings_site_path

    assert_response :success
    assert_select "h1", "General"
    assert_select "input[name=?]", "site_setting[cups_server]"
    assert_select "input[name=?]", "site_setting[matomo_url]"
    assert_select "input[name=?]", "site_setting[matomo_site_id]"
    assert_select ".status-panel"
    assert_select "table.table-scan-visits", count: 0
  end

  test "update saves matomo settings" do
    patch settings_site_path, params: {
      site_setting: {
        cups_server: "cups.example.com:631",
        matomo_url: "https://matomo.example.com/analytics/",
        matomo_site_id: "7"
      }
    }

    assert_redirected_to settings_site_path
    setting = SiteSetting.instance
    assert_equal "https://matomo.example.com/analytics/", setting.matomo_url
    assert_equal "7", setting.matomo_site_id
    assert setting.matomo_enabled?
  end

  test "update rejects partial matomo settings" do
    patch settings_site_path, params: {
      site_setting: {
        cups_server: "cups.example.com:631",
        matomo_url: "https://matomo.example.com",
        matomo_site_id: ""
      }
    }

    assert_response :unprocessable_entity
    assert_nil SiteSetting.instance.reload.matomo_url
  end

  test "update saves cups server" do
    patch settings_site_path, params: {
      site_setting: { cups_server: "192.168.1.50:631" }
    }

    assert_redirected_to settings_site_path
    assert_equal "192.168.1.50:631", SiteSetting.instance.cups_server
  end

  test "requires authentication even from whitelisted network" do
    with_network_whitelist("192.168.0.0/16") do
      delete logout_path

      get settings_site_path, env: from_network("192.168.1.50")
      assert_redirected_to login_path
    end
  end
end
