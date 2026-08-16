require "test_helper"

class ThingTrackingTest < ActiveSupport::TestCase
  test "tracked sources include qrcode and nfc" do
    assert ThingTracking.tracked?("qrcode")
    assert ThingTracking.tracked?("nfc")
    assert_not ThingTracking.tracked?("email")
    assert_not ThingTracking.tracked?(nil)
  end

  test "thing_url uses short url host and thing key" do
    with_short_url_host("http://l.ctrlh") do
      thing = things(:keyboard)
      url = ThingTracking.thing_url(thing, utm_source: ThingTracking::QR_CODE)

      assert_equal "http://l.ctrlh/#{thing.key}?utm_source=qrcode", url
    end
  end

  test "thing_url falls back to APP_HOST when short url host is unset" do
    with_app_host("https://links.example.org") do
      with_short_url_host(nil) do
        thing = things(:router)
        url = ThingTracking.thing_url(thing, utm_source: ThingTracking::QR_CODE)

        assert_equal "https://links.example.org/#{thing.key}?utm_source=qrcode", url
      end
    end
  end
end
