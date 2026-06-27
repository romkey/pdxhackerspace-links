require "test_helper"

class Things::ScanStatsTest < ActiveSupport::TestCase
  test "aggregates totals and sorts things by total descending by default" do
    things(:keyboard).update!(qr_scan_count: 2, nfc_scan_count: 1, visit_count: 10)
    things(:router).update!(qr_scan_count: 5, nfc_scan_count: 0, visit_count: 3)

    stats = Things::ScanStats.call

    assert_equal 7, stats.qr_total
    assert_equal 1, stats.nfc_total
    assert_equal 8, stats.total
    assert_equal 13, stats.visit_total
    assert_equal "total", stats.sort
    assert_equal "desc", stats.direction
    assert_equal [ "Router", "Keyboard" ], stats.things.map(&:name)
  end

  test "sorts by visits descending" do
    things(:keyboard).update!(visit_count: 2)
    things(:router).update!(visit_count: 9)

    stats = Things::ScanStats.call(sort: "visits", direction: "desc")

    assert_equal [ "Router", "Keyboard" ], stats.things.map(&:name)
  end

  test "sorts by nfc ascending" do
    things(:keyboard).update!(qr_scan_count: 0, nfc_scan_count: 2)
    things(:router).update!(qr_scan_count: 0, nfc_scan_count: 0)

    stats = Things::ScanStats.call(sort: "nfc", direction: "asc")

    assert_equal [ "Router", "Keyboard" ], stats.things.map(&:name)
  end

  test "ignores invalid sort parameters" do
    stats = Things::ScanStats.call(sort: "invalid", direction: "sideways")

    assert_equal "total", stats.sort
    assert_equal "desc", stats.direction
  end
end
