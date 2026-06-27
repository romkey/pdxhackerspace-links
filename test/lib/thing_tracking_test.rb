require "test_helper"

class ThingTrackingTest < ActiveSupport::TestCase
  test "tracked sources include qrcode and nfc" do
    assert ThingTracking.tracked?("qrcode")
    assert ThingTracking.tracked?("nfc")
    assert_not ThingTracking.tracked?("email")
    assert_not ThingTracking.tracked?(nil)
  end

  test "thing_url adds utm_source" do
    with_app_host("https://links.example.org") do
      thing = things(:keyboard)
      url = ThingTracking.thing_url(thing, utm_source: ThingTracking::QR_CODE)

      assert_equal "https://links.example.org/things/#{thing.id}?utm_source=qrcode", url
    end
  end
end
