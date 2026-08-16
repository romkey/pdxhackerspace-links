require "test_helper"

class ShortUrlTest < ActiveSupport::TestCase
  test "host falls back to APP_HOST when SHORT_URL is unset" do
    with_app_host("https://links.example.org") do
      with_short_url_host(nil) do
        assert_equal "https://links.example.org", ShortUrl.host
      end
    end
  end

  test "host uses SHORT_URL when set" do
    with_short_url_host("http://l.ctrlh") do
      assert_equal "http://l.ctrlh", ShortUrl.host
    end
  end

  test "host accepts legacy SHORT_URL_HOST when SHORT_URL is unset" do
    with_short_url_host(nil) do
      ENV["SHORT_URL_HOST"] = "http://legacy.ctrlh"
      assert_equal "http://legacy.ctrlh", ShortUrl.host
    end
  ensure
    ENV.delete("SHORT_URL_HOST")
  end

  test "display_url combines host and thing key" do
    with_short_url_host("http://l.ctrlh") do
      assert_equal "http://l.ctrlh/#{things(:router).key}", ShortUrl.display_url(things(:router))
    end
  end

  test "scan_url encodes short host, key, and utm_source" do
    with_short_url_host("http://l.ctrlh") do
      url = ShortUrl.scan_url(things(:keyboard), utm_source: "qrcode")

      assert_equal "http://l.ctrlh/#{things(:keyboard).key}?utm_source=qrcode", url
      assert_not_includes url, "/things/"
    end
  end
end
