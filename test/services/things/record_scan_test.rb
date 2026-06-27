require "test_helper"

class Things::RecordScanTest < ActiveSupport::TestCase
  test "increments qr scan count for qrcode source" do
    thing = things(:keyboard)

    assert_difference -> { thing.reload.qr_scan_count }, 1 do
      Things::RecordScan.call(thing: thing, utm_source: ThingTracking::QR_CODE)
    end

    assert_equal 0, thing.nfc_scan_count
  end

  test "increments nfc scan count for nfc source" do
    thing = things(:keyboard)

    assert_difference -> { thing.reload.nfc_scan_count }, 1 do
      Things::RecordScan.call(thing: thing, utm_source: ThingTracking::NFC)
    end

    assert_equal 0, thing.qr_scan_count
  end

  test "ignores untracked sources" do
    thing = things(:keyboard)

    assert_no_difference -> { thing.reload.qr_scan_count } do
      assert_no_difference -> { thing.nfc_scan_count } do
        Things::RecordScan.call(thing: thing, utm_source: "email")
      end
    end
  end
end
