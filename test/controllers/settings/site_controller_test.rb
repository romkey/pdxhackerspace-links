require "test_helper"

class Settings::SiteControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:local_admin))
    SiteSetting.instance.update!(cups_server: "cups.example.com:631")
  end

  test "show displays site settings" do
    things(:keyboard).update!(qr_scan_count: 3, nfc_scan_count: 1)
    things(:router).update!(qr_scan_count: 2, nfc_scan_count: 0)

    get settings_site_path

    assert_response :success
    assert_select "h1", "General"
    assert_select "input[name=?]", "site_setting[cups_server]"
    assert_select ".status-panel"
    assert_select ".text-13", text: /5 QR · 1 NFC · 6 total scans/
    assert_select ".h-section-label", text: "Scan visits"
    assert_select ".h-section-label", text: "By total"
    assert_select ".h-section-label", text: "By QR"
    assert_select ".h-section-label", text: "By NFC"
    assert_select "tr.clickable-row td.num", text: "3"
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
