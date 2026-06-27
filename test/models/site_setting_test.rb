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

  test "matomo enabled when url and site id are set" do
    setting = site_settings(:default)
    setting.update!(matomo_url: "https://matomo.example.com", matomo_site_id: "3")

    assert setting.matomo_enabled?
    assert_equal "https://matomo.example.com/", setting.matomo_tracker_base
  end

  test "matomo disabled when url or site id is blank" do
    setting = site_settings(:default)
    setting.assign_attributes(matomo_url: "https://matomo.example.com", matomo_site_id: "")

    assert_not setting.matomo_enabled?
    assert_not setting.valid?
  end

  test "requires paired matomo fields" do
    setting = site_settings(:default)
    setting.matomo_url = "https://matomo.example.com"
    setting.matomo_site_id = ""

    assert_not setting.valid?
    assert_includes setting.errors[:base], "Matomo URL and site ID must both be set or both be blank"
  end

  test "validates matomo url format" do
    setting = site_settings(:default)
    setting.assign_attributes(matomo_url: "not-a-url", matomo_site_id: "1")

    assert_not setting.valid?
    assert_includes setting.errors[:matomo_url], "must be an http or https URL"
  end

  test "validates matomo site id format" do
    setting = site_settings(:default)
    setting.assign_attributes(matomo_url: "https://matomo.example.com", matomo_site_id: "abc")

    assert_not setting.valid?
    assert_includes setting.errors[:matomo_site_id], "must be a number"
  end
end
