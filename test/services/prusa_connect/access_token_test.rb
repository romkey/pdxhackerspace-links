require "test_helper"

class PrusaConnect::AccessTokenTest < ActiveSupport::TestCase
  test "reuses a valid cached access token" do
    account = prusa_connect_accounts(:main)
    account.update!(access_token: "still-valid", access_token_expires_at: 1.hour.from_now)

    assert_no_changes -> { account.reload.refresh_token } do
      assert_equal "still-valid", PrusaConnect::AccessToken.ensure!(account)
    end
  end

  test "refreshes an expiring token and persists the rotated refresh token" do
    account = prusa_connect_accounts(:main)
    account.update!(access_token: "expired", access_token_expires_at: 1.minute.ago)

    transport = prusa_connect_token_transport(
      "/o/token/" => [
        200,
        {
          access_token: "fresh-access",
          refresh_token: "rotated-refresh",
          expires_in: 3600
        }
      ]
    )

    assert_equal "fresh-access", PrusaConnect::AccessToken.ensure!(account, transport: transport)

    account.reload
    assert_equal "fresh-access", account.access_token
    assert_equal "rotated-refresh", account.refresh_token
    assert account.access_token_expires_at > Time.current
  end

  test "force refresh exchanges the refresh token even when the access token is still valid" do
    account = prusa_connect_accounts(:main)
    account.update!(access_token: "still-valid", access_token_expires_at: 1.hour.from_now)

    transport = prusa_connect_token_transport(
      "/o/token/" => [
        200,
        { access_token: "fresh-access", refresh_token: "rotated-refresh", expires_in: 3600 }
      ]
    )

    assert_equal "fresh-access", PrusaConnect::AccessToken.force_refresh!(account, transport: transport)
    assert_equal "rotated-refresh", account.reload.refresh_token
  end

  test "surfaces invalid_grant as an actionable auth error" do
    account = prusa_connect_accounts(:main)
    account.update!(access_token: nil, access_token_expires_at: nil)

    transport = prusa_connect_token_transport(
      "/o/token/" => [ 400, { error: "invalid_grant", error_description: "Token is invalid" } ]
    )

    error = assert_raises(PrusaConnect::Client::AuthenticationError) do
      PrusaConnect::AccessToken.ensure!(account, transport: transport)
    end

    assert_match "refresh token is no longer valid", error.message
  end
end
