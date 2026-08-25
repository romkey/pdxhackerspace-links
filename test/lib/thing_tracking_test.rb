require "test_helper"

class ThingTrackingTest < ActiveSupport::TestCase
  test "tracked sources include qrcode and nfc" do
    assert ThingTracking.tracked?("qrcode")
    assert ThingTracking.tracked?("nfc")
    assert_not ThingTracking.tracked?("email")
    assert_not ThingTracking.tracked?(nil)
  end

  test "thing_url uses short url host and abbreviated scan param" do
    with_short_url_host("http://l.ctrlh") do
      thing = things(:keyboard)
      url = ThingTracking.thing_url(thing, utm_source: ThingTracking::QR_CODE)

      assert_equal "http://l.ctrlh/#{thing.key}?q", url
    end
  end

  test "thing_url uses n abbrev for nfc" do
    with_short_url_host("http://l.ctrlh") do
      thing = things(:router)
      url = ThingTracking.thing_url(thing, utm_source: ThingTracking::NFC)

      assert_equal "http://l.ctrlh/#{thing.key}?n", url
    end
  end

  test "thing_url falls back to APP_HOST when short url is unset" do
    with_app_host("https://links.example.org") do
      with_short_url_host(nil) do
        thing = things(:router)
        url = ThingTracking.thing_url(thing, utm_source: ThingTracking::QR_CODE)

        assert_equal "https://links.example.org/#{thing.key}?q", url
      end
    end
  end

  test "full_thing_url uses APP_HOST and thing path with utm_source" do
    with_app_host("https://links.example.org") do
      thing = things(:keyboard)
      url = ThingTracking.full_thing_url(thing, utm_source: ThingTracking::QR_CODE)

      assert_equal "https://links.example.org/things/#{thing.slug}?utm_source=qrcode", url
    end
  end

  test "scan_utm_source_from resolves abbreviated params" do
    assert_equal ThingTracking::QR_CODE, ThingTracking.scan_utm_source_from({ "q" => "" })
    assert_equal ThingTracking::NFC, ThingTracking.scan_utm_source_from({ "n" => "" })
    assert_equal ThingTracking::QR_CODE, ThingTracking.scan_utm_source_from({ "utm_source" => "qrcode" })
    assert_nil ThingTracking.scan_utm_source_from({})
  end
end
