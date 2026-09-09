require "test_helper"

class PrusaConnectAccountTest < ActiveSupport::TestCase
  test "requires a name and refresh token" do
    account = PrusaConnectAccount.new

    assert_not account.valid?
    assert_includes account.errors[:name], "can't be blank"
    assert_includes account.errors[:refresh_token], "can't be blank"
  end

  test "names must be unique" do
    duplicate = PrusaConnectAccount.new(
      name: prusa_connect_accounts(:main).name,
      refresh_token: "another-token"
    )

    assert_not duplicate.valid?
  end

  test "access token validity respects the expiry skew" do
    account = prusa_connect_accounts(:main)
    account.access_token = "token"
    account.access_token_expires_at = 30.seconds.from_now

    assert_not account.access_token_valid?

    account.access_token_expires_at = 2.minutes.from_now
    assert account.access_token_valid?
  end
end
