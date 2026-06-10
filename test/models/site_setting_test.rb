require "test_helper"

class SiteSettingTest < ActiveSupport::TestCase
  test "requires cups server" do
    setting = SiteSetting.new(cups_server: "")
    assert_not setting.valid?
  end

  test "instance returns persisted record" do
    assert_no_difference -> { SiteSetting.count } do
      setting = SiteSetting.instance
      assert_equal site_settings(:default).cups_server, setting.cups_server
    end
  end

  test "default cups server ignores blank environment variable" do
    old = ENV["CUPS_SERVER"]
    ENV["CUPS_SERVER"] = ""
    assert_equal "localhost:631", SiteSetting.default_cups_server
  ensure
    ENV["CUPS_SERVER"] = old
  end
end
