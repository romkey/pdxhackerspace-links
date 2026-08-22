ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

class ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper
end

class ActiveSupport::TestCase
  parallelize(workers: :number_of_processors)

  fixtures :all

  def sign_in_as(user)
    with_local_auth(email: user.email, password: "secret") do
      post local_login_path, params: { email: user.email, password: "secret" }
    end
  end

  def with_local_auth(email:, password: "secret")
    previous = %w[LOCAL_AUTH_EMAIL LOCAL_AUTH_PASSWORD LOCAL_AUTH_NAME].index_with { |key| ENV[key] }
    ENV["LOCAL_AUTH_EMAIL"] = email
    ENV["LOCAL_AUTH_PASSWORD"] = password
    ENV["LOCAL_AUTH_NAME"] = "Test User"
    yield
  ensure
    previous.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end

  def with_app_host(app_host)
    previous = ENV["APP_HOST"]
    ENV["APP_HOST"] = app_host
    yield
  ensure
    previous.nil? ? ENV.delete("APP_HOST") : ENV["APP_HOST"] = previous
  end

  def with_short_url_host(short_url_host)
    previous_short = ENV["SHORT_URL"]
    previous_host = ENV["SHORT_URL_HOST"]
    if short_url_host.nil?
      ENV.delete("SHORT_URL")
      ENV.delete("SHORT_URL_HOST")
    else
      ENV["SHORT_URL"] = short_url_host
      ENV.delete("SHORT_URL_HOST")
    end
    yield
  ensure
    previous_short.nil? ? ENV.delete("SHORT_URL") : ENV["SHORT_URL"] = previous_short
    previous_host.nil? ? ENV.delete("SHORT_URL_HOST") : ENV["SHORT_URL_HOST"] = previous_host
  end

  def attach_ar_anchor(thing, filename: "ar_anchor.png")
    thing.ar_anchor.attach(
      io: file_fixture(filename).open,
      filename: filename,
      content_type: "image/png"
    )
    thing
  end

  def with_network_whitelist(value)
    previous = ENV["NETWORK_WHITELIST"]
    value.nil? ? ENV.delete("NETWORK_WHITELIST") : ENV["NETWORK_WHITELIST"] = value
    Links::NetworkWhitelist.reset!
    yield
  ensure
    previous.nil? ? ENV.delete("NETWORK_WHITELIST") : ENV["NETWORK_WHITELIST"] = previous
    Links::NetworkWhitelist.reset!
  end

  def from_network(ip)
    { "REMOTE_ADDR" => ip }
  end

  def through_proxy(proxy_ip, client_ip:)
    {
      "REMOTE_ADDR" => proxy_ip,
      "HTTP_X_FORWARDED_FOR" => client_ip
    }
  end

  def with_trusted_reverse_proxies(value)
    previous_env = ENV["TRUSTED_REVERSE_PROXIES"]
    previous_config = Rails.application.config.action_dispatch.trusted_proxies
    value.nil? ? ENV.delete("TRUSTED_REVERSE_PROXIES") : ENV["TRUSTED_REVERSE_PROXIES"] = value
    Links::TrustedReverseProxies.reset!
    Links::TrustedReverseProxies.apply!
    yield
  ensure
    previous_env.nil? ? ENV.delete("TRUSTED_REVERSE_PROXIES") : ENV["TRUSTED_REVERSE_PROXIES"] = previous_env
    Links::TrustedReverseProxies.reset!
    Rails.application.config.action_dispatch.trusted_proxies = previous_config
  end

  # Swaps a class method for the duration of the block.
  def stubbing(klass, method_name, replacement)
    original = klass.method(method_name)
    klass.define_singleton_method(method_name) { |*args, **kwargs| replacement.call(*args, **kwargs) }
    yield
  ensure
    klass.define_singleton_method(method_name, original)
  end

  # Builds a transport for Unifi::Client that answers from a canned map of
  # "/path?query" (or just "/path") to [status, body]. Bodies are JSON-encoded
  # unless already a string. Unlisted paths fail the test rather than hang.
  def unifi_transport(responses)
    lambda do |uri, _headers|
      status, body = responses[uri.request_uri] || responses[uri.path]
      raise "Unexpected UniFi request: #{uri.request_uri}" if status.nil?

      [ status, body.is_a?(String) ? body : body.to_json ]
    end
  end

  def unifi_page(items)
    { "offset" => 0, "limit" => 200, "count" => items.size, "totalCount" => items.size, "data" => items }
  end

  def zigbee2mqtt_transport(devices:, last_seen: {})
    lambda do
      Zigbee2mqtt::Client::Response.new(devices: devices, last_seen: last_seen)
    end
  end

  def with_fake_cups_client(server: "cups.example.com:631", fail_print: false, &block)
    runner = lambda do |*_args|
      case _args[1]
      when "lp"
        if fail_print
          [ "", "lp: unable to connect", Struct.new(:success?).new(false) ]
        else
          [ "request id is Test-1 (1 file(s))\n", "", Struct.new(:success?).new(true) ]
        end
      when "lpstat"
        [ "", "", Struct.new(:success?).new(true) ]
      else
        [ "", "", Struct.new(:success?).new(false) ]
      end
    end
    client = Cups::Client.new(server: server, runner: runner)
    patches = [
      [ Things::PrintLabel, :call ],
      [ Printers::PrintTestLabel, :call ]
    ].map do |klass, method_name|
      original = klass.method(method_name)
      klass.define_singleton_method(method_name) do |**kwargs|
        original.call(**kwargs, cups_client: kwargs.fetch(:cups_client, client))
      end
      [ klass, method_name, original ]
    end

    yield client
  ensure
    patches&.each do |klass, method_name, original|
      klass.define_singleton_method(method_name, original)
    end
  end
end
