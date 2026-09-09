require "test_helper"

class PrusaConnect::TestConnectionTest < ActiveSupport::TestCase
  class StubClient
    def initialize(count) = @count = count
    def printer_count = @count
  end

  test "reports the printer count on success" do
    account = prusa_connect_accounts(:main)
    result = PrusaConnect::TestConnection.call(
      prusa_connect_account: account,
      client: StubClient.new(3)
    )

    assert result.success?
    assert_match "3 printers", result.message
  end

  test "reports auth failures" do
    account = prusa_connect_accounts(:main)
    failing_client = Class.new do
      def printer_count
        raise PrusaConnect::Client::AuthenticationError, "Token rejected"
      end
    end.new

    result = PrusaConnect::TestConnection.call(
      prusa_connect_account: account,
      client: failing_client
    )

    assert_not result.success?
    assert_match "Token rejected", result.message
  end
end
