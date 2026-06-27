require "test_helper"

class Settings::ScanVisitsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:local_admin))
    things(:keyboard).update!(qr_scan_count: 3, nfc_scan_count: 1)
    things(:router).update!(qr_scan_count: 2, nfc_scan_count: 0)
  end

  test "show displays scan visit totals and table" do
    get settings_scan_visits_path

    assert_response :success
    assert_select "h1", "Scan visits"
    assert_select ".text-13", text: /5 QR · 1 NFC · 6 total/
    assert_select "table.table-scan-visits"
    assert_select "tr.clickable-row", count: Thing.count
    assert_select "tr.clickable-row td.num", text: "3"
  end

  test "sorts by total descending by default" do
    get settings_scan_visits_path

    assert_response :success
    rows = css_select("tbody tr.clickable-row td.fw-medium").map(&:text)
    assert_equal [ "Keyboard", "Router" ], rows
  end

  test "sorts by qr ascending" do
    get settings_scan_visits_path(sort: "qr", direction: "asc")

    rows = css_select("tbody tr.clickable-row td.fw-medium").map(&:text)
    assert_equal [ "Router", "Keyboard" ], rows
    assert_select "th.num a.fw-medium", text: /QR/
  end

  test "sorts by name ascending" do
    get settings_scan_visits_path(sort: "name", direction: "asc")

    rows = css_select("tbody tr.clickable-row td.fw-medium").map(&:text)
    assert_equal Thing.order(:name).pluck(:name), rows
  end

  test "requires authentication" do
    delete logout_path

    get settings_scan_visits_path
    assert_redirected_to login_path
  end
end
