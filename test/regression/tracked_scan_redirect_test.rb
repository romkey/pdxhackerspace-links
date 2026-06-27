require "test_helper"

class TrackedScanRedirectRegressionTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:local_admin))
  end

  test "tracked scan redirects to clean url without utm_source" do
    thing = things(:keyboard)

    assert_difference -> { thing.reload.qr_scan_count }, 1 do
      assert_difference -> { thing.reload.visit_count }, 1 do
        get thing_path(thing, utm_source: "qrcode")
      end
    end

    assert_redirected_to thing_path(thing)
    assert_no_match(/utm_source=/, response.headers["Location"])

    follow_redirect!

    assert_response :success
    assert_equal thing_path(thing), request.fullpath

    assert_no_difference -> { thing.reload.qr_scan_count } do
      get thing_path(thing)
    end

    assert_difference -> { thing.reload.visit_count }, 1 do
      get thing_path(thing)
    end
  end

  test "reload after tracked scan does not increment qr count again" do
    thing = things(:router)

    get thing_path(thing, utm_source: "nfc")
    follow_redirect!

    assert_equal 1, thing.reload.nfc_scan_count

    get thing_path(thing)
    assert_equal 1, thing.reload.nfc_scan_count
  end

  test "tracked scan with single link shows redirect countdown on clean url" do
    thing = things(:keyboard)
    thing.links.find_by(link_type: :slack).destroy!

    get thing_path(thing, utm_source: "qrcode")
    follow_redirect!

    assert_response :success
    assert_select "[data-controller='redirect-countdown']"
    assert_select "[data-redirect-countdown-url-value=?]", thing_links(:keyboard_wiki).url
  end
end
