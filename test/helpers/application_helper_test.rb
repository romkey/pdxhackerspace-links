require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  include ApplicationHelper

  test "relative_time shows time only for today" do
    time = Time.zone.parse("2026-08-24 15:05:00")

    travel_to Time.zone.parse("2026-08-24 18:00:00") do
      html = relative_time(time)
      assert_includes html, "3:05 PM"
      assert_includes html, time.to_fs(:long)
    end
  end

  test "relative_time shows yesterday" do
    time = Time.zone.parse("2026-08-23 12:00:00")

    travel_to Time.zone.parse("2026-08-24 12:00:00") do
      assert_includes relative_time(time), "Yesterday"
    end
  end

  test "relative_time shows days ago within a week" do
    time = Time.zone.parse("2026-08-20 12:00:00")

    travel_to Time.zone.parse("2026-08-24 12:00:00") do
      assert_includes relative_time(time), "4 days ago"
    end
  end
end
