require "test_helper"

class AppHostTest < ActiveSupport::TestCase
  test "parses https host without port" do
    assert_equal(
      { host: "links.pdxhackerspace.org", protocol: "https" },
      AppHost.parse("https://links.pdxhackerspace.org")
    )
  end

  test "parses http host with non-default port" do
    assert_equal(
      { host: "localhost", protocol: "http", port: 3000 },
      AppHost.parse("http://localhost:3000")
    )
  end

  test "url_options reads APP_HOST from environment" do
    with_app_host("https://labels.example.com") do
      assert_equal(
        { host: "labels.example.com", protocol: "https" },
        AppHost.url_options
      )
    end
  end

  test "url_options does not fall back to example.com" do
    with_app_host("https://links.regression.test") do
      options = AppHost.url_options

      assert_equal "links.regression.test", options[:host]
      assert_not_equal "example.com", options[:host]
    end
  end
end
