require "test_helper"

class ShortUrlTest < ActiveSupport::TestCase
  test "host falls back to APP_HOST when SHORT_URL_HOST is unset" do
    with_app_host("https://links.example.org") do
      with_short_url_host(nil) do
        assert_equal "https://links.example.org", ShortUrl.host
      end
    end
  end

  test "host uses SHORT_URL_HOST when set" do
    with_short_url_host("http://l.ctrlh") do
      assert_equal "http://l.ctrlh", ShortUrl.host
    end
  end

  test "display_url combines host and thing key" do
    with_short_url_host("http://l.ctrlh") do
      assert_equal "http://l.ctrlh/#{things(:router).key}", ShortUrl.display_url(things(:router))
    end
  end
end
