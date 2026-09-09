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

    assert_equal 2, records.size
    assert_equal "Page one", records.first.name
    assert_equal "Page two", records.second.name
  end

  test "raises an authentication error for a rejected token" do
    client = build_client(responses: {
      "/app/printers?limit=1&offset=0" => [ 401, { "message" => "Unauthorized" } ]
    })

    error = assert_raises(PrusaConnect::Client::AuthenticationError) { client.printer_count }
    assert_match "rejected the access token", error.message
  end

  test "raises a readable error for a non-JSON response" do
    client = build_client(responses: {
      "/app/printers?limit=1&offset=0" => [ 200, "<html>not json</html>" ]
    })

    error = assert_raises(PrusaConnect::Client::Error) { client.printer_count }
    assert_match "not JSON", error.message
  end
end
