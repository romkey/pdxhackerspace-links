require "test_helper"

class Links::TrustedReverseProxiesTest < ActiveSupport::TestCase
  test "not configured when env is blank" do
    with_trusted_reverse_proxies(nil) do
      assert_not Links::TrustedReverseProxies.configured?
    end
  end

  test "configured when env has networks" do
    with_trusted_reverse_proxies("198.51.100.0/24") do
      assert Links::TrustedReverseProxies.configured?
    end
  end

  test "all merges env entries with rails defaults" do
    with_trusted_reverse_proxies("198.51.100.10") do
      proxies = Links::TrustedReverseProxies.all
      assert_includes proxies.map(&:to_s), "198.51.100.10"
      assert_includes proxies.map(&:to_s), "10.0.0.0"
    end
  end

  test "all returns defaults when env is blank" do
    with_trusted_reverse_proxies(nil) do
      assert_equal ActionDispatch::RemoteIp::TRUSTED_PROXIES, Links::TrustedReverseProxies.all
    end
  end

  test "apply sets action dispatch trusted proxies" do
    with_trusted_reverse_proxies("198.51.100.10") do
      Links::TrustedReverseProxies.apply!
      assert_includes Rails.application.config.action_dispatch.trusted_proxies.map(&:to_s), "198.51.100.10"
    end
  end

  test "ignores invalid entries" do
    with_trusted_reverse_proxies("not-an-ip,198.51.100.10") do
      assert_equal [ "198.51.100.10" ], Links::TrustedReverseProxies.networks.map(&:to_s)
    end
  end

  test "parses comma and whitespace separated entries" do
    with_trusted_reverse_proxies("198.51.100.10, 203.0.113.0/24") do
      labels = Links::TrustedReverseProxies.networks.map(&:to_s)
      assert_includes labels, "198.51.100.10"
      assert Links::TrustedReverseProxies.networks.any? { |network| network.include?(IPAddr.new("203.0.113.50")) }
    end
  end

  test "reset clears cached networks" do
    with_trusted_reverse_proxies("198.51.100.10") do
      assert Links::TrustedReverseProxies.configured?

      ENV.delete("TRUSTED_REVERSE_PROXIES")
      Links::TrustedReverseProxies.reset!

      assert_not Links::TrustedReverseProxies.configured?
    end
  end

  test "remote ip resolves client behind configured public proxy" do
    proxies = Links::TrustedReverseProxies.parse("198.51.100.10") + ActionDispatch::RemoteIp::TRUSTED_PROXIES
    env = proxy_env("198.51.100.10", "192.168.1.50")

    ActionDispatch::RemoteIp.new(success_app, true, proxies).call(env)

    assert_equal "192.168.1.50", ActionDispatch::Request.new(env).remote_ip
  end

  test "remote ip ignores x-forwarded-for from untrusted public proxy" do
    proxies = Links::TrustedReverseProxies.parse("198.51.100.10") + ActionDispatch::RemoteIp::TRUSTED_PROXIES
    env = proxy_env("203.0.113.50", "192.168.1.50")

    ActionDispatch::RemoteIp.new(success_app, true, proxies).call(env)

    assert_equal "203.0.113.50", ActionDispatch::Request.new(env).remote_ip
  end

  test "remote ip resolves client behind default private network proxy" do
    env = proxy_env("10.0.0.1", "192.168.1.50")

    ActionDispatch::RemoteIp.new(success_app).call(env)

    assert_equal "192.168.1.50", ActionDispatch::Request.new(env).remote_ip
  end

  test "remote ip uses last x-forwarded-for entry when earlier hops are trusted" do
    env = Rack::MockRequest.env_for(
      "/",
      "REMOTE_ADDR" => "10.0.0.1",
      "HTTP_X_FORWARDED_FOR" => "192.168.1.50"
    )

    ActionDispatch::RemoteIp.new(success_app).call(env)

    assert_equal "192.168.1.50", ActionDispatch::Request.new(env).remote_ip
  end

  test "remote ip returns outer untrusted hop when client ip is filtered as trusted" do
    env = Rack::MockRequest.env_for(
      "/",
      "REMOTE_ADDR" => "10.0.0.1",
      "HTTP_X_FORWARDED_FOR" => "203.0.113.50, 192.168.1.50"
    )

    ActionDispatch::RemoteIp.new(success_app).call(env)

    assert_equal "203.0.113.50", ActionDispatch::Request.new(env).remote_ip
  end

  private

  def success_app
    @success_app ||= ->(_env) { [ 200, {}, [ "ok" ] ] }
  end

  def proxy_env(proxy_ip, client_ip)
    Rack::MockRequest.env_for(
      "/",
      "REMOTE_ADDR" => proxy_ip,
      "HTTP_X_FORWARDED_FOR" => client_ip
    )
  end
end
