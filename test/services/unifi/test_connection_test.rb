require "test_helper"

class Unifi::TestConnectionTest < ActiveSupport::TestCase
  class StubClient
    def initialize(version) = @version = version
    def application_version = @version
  end

  class FailingClient
    def initialize(message) = @message = message
    def application_version = raise(Unifi::Client::AuthenticationError, @message)
  end

  test "reports the version of each enabled application" do
    result = Unifi::TestConnection.call(
      unifi_controller: unifi_controllers(:udm),
      network_client: StubClient.new("9.3.45"),
      protect_client: StubClient.new("7.2.105")
    )

    assert result.success?
    assert_equal({ "Network" => "9.3.45", "Protect" => "7.2.105" }, result.versions)
    assert_match "Network 9.3.45 and Protect 7.2.105", result.message
  end

  test "only probes the applications the controller has enabled" do
    result = Unifi::TestConnection.call(
      unifi_controller: unifi_controllers(:network_only),
      network_client: StubClient.new("9.3.45"),
      protect_client: FailingClient.new("should not be called")
    )

    assert result.success?
    assert_equal %w[Network], result.versions.keys
  end

  test "reports a failure for the application that could not be reached" do
    result = Unifi::TestConnection.call(
      unifi_controller: unifi_controllers(:udm),
      network_client: StubClient.new("9.3.45"),
      protect_client: FailingClient.new("UniFi rejected the API key (HTTP 401)")
    )

    assert_not result.success?
    assert_match "Connected to Network 9.3.45", result.message
    assert_match "Protect: UniFi rejected the API key", result.message
  end
end
