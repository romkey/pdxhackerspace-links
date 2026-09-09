require "test_helper"

class PrusaConnect::ClientTest < ActiveSupport::TestCase
  def build_client(responses:, account: prusa_connect_accounts(:main))
    account.update!(access_token: "valid-token", access_token_expires_at: 1.hour.from_now)
    PrusaConnect::Client.new(
      account: account,
      transport: prusa_connect_transport(responses),
      sleeper: proc { |_| }
    )
  end

  test "sends the bearer token and parses JSON" do
    captured = nil
    transport = lambda do |uri, headers|
      captured = headers
      [ 200, { "pager" => { "total" => 0 }, "printers" => [] }.to_json, {} ]
    end

    account = prusa_connect_accounts(:main)
    account.update!(access_token: "valid-token", access_token_expires_at: 1.hour.from_now)
    PrusaConnect::Client.new(account: account, transport: transport, sleeper: proc { |_| }).printer_count

    assert_equal "Bearer valid-token", captured["Authorization"]
    assert_equal "application/json", captured["Accept"]
  end

  test "paginates the printer list across pages" do
    client = build_client(responses: {
      "/app/printers?limit=50&offset=0" => [
        200,
        {
          "printers" => [ { "uuid" => "11111111-1111-4111-8111-111111111111" } ],
          "pager" => { "limit" => 50, "offset" => 0, "total" => 2 }
        }
      ],
      "/app/printers/11111111-1111-4111-8111-111111111111" => [
        200,
        {
          "uuid" => "11111111-1111-4111-8111-111111111111",
          "name" => "Page one",
          "network_info" => { "mac" => "94:2a:6f:26:c6:ca" }
        }
      ],
      "/app/printers?limit=50&offset=1" => [
        200,
        {
          "printers" => [ { "uuid" => "22222222-2222-4222-8222-222222222222" } ],
          "pager" => { "limit" => 50, "offset" => 1, "total" => 2 }
        }
      ],
      "/app/printers/22222222-2222-4222-8222-222222222222" => [
        200,
        {
          "uuid" => "22222222-2222-4222-8222-222222222222",
          "name" => "Page two",
          "network_info" => { "mac" => "d0:21:f9:8b:6a:ed" }
        }
      ]
    })

    records = client.printer_records

    assert_equal 2, records.records.size
    assert_empty records.errors
    assert_equal "Page one", records.records.first.name
    assert_equal "Page two", records.records.second.name
  end

  test "skips unavailable printers instead of failing the whole fetch" do
    client = build_client(responses: {
      "/app/printers?limit=50&offset=0" => [
        200,
        {
          "printers" => [
            { "uuid" => "11111111-1111-4111-8111-111111111111", "name" => "Good printer" },
            { "uuid" => "22222222-2222-4222-8222-222222222222", "name" => "Missing printer" }
          ],
          "pager" => { "limit" => 50, "offset" => 0, "total" => 2 }
        }
      ],
      "/app/printers/11111111-1111-4111-8111-111111111111" => [
        200,
        {
          "uuid" => "11111111-1111-4111-8111-111111111111",
          "name" => "Good printer",
          "network_info" => { "mac" => "94:2a:6f:26:c6:ca" }
        }
      ],
      "/app/printers/22222222-2222-4222-8222-222222222222" => [ 404, { "message" => "Not found" } ]
    })

    response = client.printer_records

    assert_equal 1, response.records.size
    assert_equal 1, response.errors.size
    assert_equal(
      %w[11111111-1111-4111-8111-111111111111 22222222-2222-4222-8222-222222222222],
      response.listed_external_ids
    )
    assert_match "Missing printer", response.errors.first
    assert_match "22222222-2222-4222-8222-222222222222", response.errors.first
  end

  test "refreshes the access token and retries after a rejected token" do
    account = prusa_connect_accounts(:main)
    account.update!(access_token: "stale-token", access_token_expires_at: 1.hour.from_now)

    token_transport = prusa_connect_token_transport(
      "/o/token/" => [
        200,
        { access_token: "fresh-token", refresh_token: "rotated-refresh", expires_in: 3600 }
      ]
    )

    api_calls = 0
    transport = lambda do |uri, headers|
      api_calls += 1
      if headers["Authorization"] == "Bearer stale-token"
        [ 401, { "message" => "Unauthorized" }.to_json, {} ]
      else
        [ 200, { "pager" => { "total" => 1 }, "printers" => [] }.to_json, {} ]
      end
    end

    client = PrusaConnect::Client.new(
      account: account,
      transport: transport,
      access_token_service: Class.new do
        define_singleton_method(:ensure!) { |acct, **| acct.access_token }
        define_singleton_method(:force_refresh!) do |acct, **|
          PrusaConnect::AccessToken.force_refresh!(acct, transport: token_transport)
        end
      end,
      sleeper: proc { |_| }
    )

    assert_equal 1, client.printer_count
    assert_equal 2, api_calls
    assert_equal "fresh-token", account.reload.access_token
  end

  test "raises an authentication error when the token is rejected after refresh" do
    client = build_client(responses: {
      "/app/printers?limit=1&offset=0" => [ 401, { "message" => "Unauthorized" } ]
    })

    token_transport = prusa_connect_token_transport(
      "/o/token/" => [ 400, { error: "invalid_grant" } ]
    )

    client = PrusaConnect::Client.new(
      account: prusa_connect_accounts(:main).tap { |account|
        account.update!(access_token: "stale-token", access_token_expires_at: 1.hour.from_now)
      },
      transport: prusa_connect_transport(
        "/app/printers?limit=1&offset=0" => [ 401, { "message" => "Unauthorized" } ]
      ),
      access_token_service: Class.new do
        define_singleton_method(:ensure!) { |acct, **| acct.access_token }
        define_singleton_method(:force_refresh!) do |acct, **|
          PrusaConnect::AccessToken.force_refresh!(acct, transport: token_transport)
        end
      end,
      sleeper: proc { |_| }
    )

    error = assert_raises(PrusaConnect::Client::AuthenticationError) { client.printer_count }
    assert_match "refresh token is no longer valid", error.message
  end

  test "raises a readable error for a non-JSON response" do
    client = build_client(responses: {
      "/app/printers?limit=1&offset=0" => [ 200, "<html>not json</html>" ]
    })

    error = assert_raises(PrusaConnect::Client::Error) { client.printer_count }
    assert_match "not JSON", error.message
  end
end
