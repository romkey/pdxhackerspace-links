require "test_helper"

class Unifi::ClientTest < ActiveSupport::TestCase
  def build_client(transport:, **overrides)
    Unifi::Client.new(
      host: "unifi.example.com",
      api_key: "secret-key",
      base_path: "/proxy/network/integration",
      transport: transport,
      **overrides
    )
  end

  test "requests the base path and parses JSON" do
    client = build_client(transport: unifi_transport(
      "/proxy/network/integration/v1/info" => [ 200, { "applicationVersion" => "9.3.45" } ]
    ))

    assert_equal "9.3.45", client.get("/v1/info")["applicationVersion"]
  end

  test "sends the API key and accepts JSON" do
    captured = nil
    transport = lambda do |_uri, headers|
      captured = headers
      [ 200, "{}" ]
    end

    build_client(transport: transport).get("/v1/info")

    assert_equal "secret-key", captured["X-API-KEY"]
    assert_equal "application/json", captured["Accept"]
  end

  test "builds an HTTPS URL with the configured port and query" do
    captured = nil
    transport = lambda do |uri, _headers|
      captured = uri
      [ 200, "{}" ]
    end

    build_client(transport: transport, port: 8443).get("/v1/sites", offset: 0, limit: 200)

    assert_equal "https", captured.scheme
    assert_equal "unifi.example.com", captured.host
    assert_equal 8443, captured.port
    assert_equal "/proxy/network/integration/v1/sites", captured.path
    assert_equal "limit=200&offset=0", captured.query
  end

  test "raises an authentication error for a rejected key" do
    client = build_client(transport: unifi_transport("/proxy/network/integration/v1/info" => [ 401, "{}" ]))

    error = assert_raises(Unifi::Client::AuthenticationError) { client.get("/v1/info") }
    assert_match "rejected the API key", error.message
  end

  test "raises a not found error for a missing endpoint" do
    client = build_client(transport: unifi_transport("/proxy/network/integration/v1/fobs" => [ 404, "{}" ]))

    assert_raises(Unifi::Client::NotFoundError) { client.get("/v1/fobs") }
  end

  test "includes the UniFi error message for other failures" do
    body = { "code" => "INTERNAL", "message" => "Something broke", "statusCode" => 500 }
    client = build_client(transport: unifi_transport("/proxy/network/integration/v1/info" => [ 500, body ]))

    error = assert_raises(Unifi::Client::Error) { client.get("/v1/info") }
    assert_match "HTTP 500", error.message
    assert_match "Something broke", error.message
  end

  test "raises when the response is not JSON" do
    client = build_client(transport: unifi_transport(
      "/proxy/network/integration/v1/info" => [ 200, "<html>login</html>" ]
    ))

    assert_raises(Unifi::Client::Error) { client.get("/v1/info") }
  end

  test "reports the status, content type, and body when the response is not JSON" do
    html = "<html>\n  <head><title>429 Too Many Requests</title></head>\n</html>"
    transport = ->(_uri, _headers) { [ 200, html, { "Content-Type" => "text/html; charset=utf-8" } ] }

    error = assert_raises(Unifi::Client::Error) { build_client(transport: transport).get("/v1/info") }

    assert_match "HTTP 200", error.message
    assert_match "text/html", error.message
    assert_match "429 Too Many Requests", error.message
  end

  test "explains the console request ceiling when throttled" do
    transport = ->(_uri, _headers) { [ 429, { "message" => "Too many requests" }.to_json, {} ] }
    client = build_client(transport: transport, sleeper: ->(_seconds) { })

    error = assert_raises(Unifi::Client::RateLimitedError) { client.get("/v1/info") }

    assert_match "HTTP 429", error.message
    assert_match "ten requests a second", error.message
  end

  test "retries a throttled request and honours Retry-After" do
    responses = [
      [ 429, "{}", { "Retry-After" => "2" } ],
      [ 200, { "applicationVersion" => "9.3.45" }.to_json, {} ]
    ]
    slept = []
    client = build_client(transport: ->(_uri, _headers) { responses.shift }, sleeper: ->(s) { slept << s })

    assert_equal "9.3.45", client.get("/v1/info")["applicationVersion"]
    assert_equal [ 2.0 ], slept
  end

  test "backs off exponentially when the console sends no Retry-After" do
    responses = [ [ 429, "{}", {} ], [ 429, "{}", {} ], [ 200, "{}", {} ] ]
    slept = []
    client = build_client(transport: ->(_uri, _headers) { responses.shift }, sleeper: ->(s) { slept << s })

    client.get("/v1/info")

    assert_equal [ 1, 2 ], slept
  end

  test "gives up after exhausting its retries" do
    attempts = 0
    transport = lambda do |_uri, _headers|
      attempts += 1
      [ 429, "{}", {} ]
    end

    client = build_client(transport: transport, sleeper: ->(_seconds) { })

    assert_raises(Unifi::Client::RateLimitedError) { client.get("/v1/info") }
    assert_equal Unifi::Client::MAX_ATTEMPTS, attempts
  end

  test "paces requests through the rate limiter it is given" do
    now = 0.0
    slept = []
    limiter = Unifi::RateLimiter.new(
      max_requests: 1,
      period: 1.0,
      clock: -> { now },
      sleeper: ->(seconds) { slept << seconds; now += seconds }
    )
    client = build_client(transport: ->(_uri, _headers) { [ 200, "{}" ] }, rate_limiter: limiter)

    2.times { client.get("/v1/info") }

    assert_equal [ 1.0 ], slept
  end

  test "treats an empty body as an empty object" do
    client = build_client(transport: unifi_transport("/proxy/network/integration/v1/info" => [ 200, "" ]))

    assert_equal({}, client.get("/v1/info"))
  end
end
