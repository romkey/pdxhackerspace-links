require "test_helper"

class MatomoTrackingRegressionTest < ActionDispatch::IntegrationTest
  setup do
    SiteSetting.instance.update!(matomo_url: nil, matomo_site_id: nil)
  end

  test "layout includes matomo tracking when configured" do
    SiteSetting.instance.update!(
      matomo_url: "https://matomo.regression.test/",
      matomo_site_id: "42"
    )

    get login_path

    assert_response :success
    assert_match(/matomo\.regression\.test/, response.body)
    assert_match(/setSiteId.*42/m, response.body)
    assert_match(/turbo:load/, response.body)
  end

  test "layout omits matomo tracking when not configured" do
    get login_path

    assert_response :success
    assert_no_match(/_paq/, response.body)
    assert_no_match(/matomo\.js/, response.body)
  end

  test "navbar link reads Settings" do
    sign_in_as(users(:local_admin))

    get things_path

    assert_select "a[href=?]", settings_root_path, text: "Settings"
    assert_select "a[href=?]", settings_root_path, text: "Site settings", count: 0
  end
end
