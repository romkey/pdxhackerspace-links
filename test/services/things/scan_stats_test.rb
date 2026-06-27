require "test_helper"

class Things::ScanStatsTest < ActiveSupport::TestCase
  test "aggregates totals and sorts things" do
    things(:keyboard).update!(qr_scan_count: 2, nfc_scan_count: 1)
    things(:router).update!(qr_scan_count: 5, nfc_scan_count: 0)

    stats = Things::ScanStats.call

    assert_equal 7, stats.qr_total
    assert_equal 1, stats.nfc_total
    assert_equal 8, stats.total
    assert_equal [ "Router", "Keyboard" ], stats.by_total.map(&:name)
    assert_equal [ "Router", "Keyboard" ], stats.by_qr.map(&:name)
    assert_equal [ "Keyboard", "Router" ], stats.by_nfc.map(&:name)
  end
end
