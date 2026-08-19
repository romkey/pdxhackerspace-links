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

  test "treats an empty body as an empty object" do
    client = build_client(transport: unifi_transport("/proxy/network/integration/v1/info" => [ 200, "" ]))

    assert_equal({}, client.get("/v1/info"))
  end
end
