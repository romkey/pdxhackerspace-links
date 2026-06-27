require "test_helper"

class Links::NetworkWhitelistTest < ActiveSupport::TestCase
  test "not configured when env is blank" do
    with_network_whitelist(nil) do
      assert_not Links::NetworkWhitelist.configured?
    end
  end

  test "configured when env has networks" do
    with_network_whitelist("192.168.0.0/16") do
      assert Links::NetworkWhitelist.configured?
    end
  end

  test "includes ip in cidr block" do
    with_network_whitelist("192.168.0.0/16") do
      assert Links::NetworkWhitelist.includes?("192.168.50.10")
      assert_not Links::NetworkWhitelist.includes?("10.0.0.1")
    end
  end

  test "includes exact ip address" do
    with_network_whitelist("10.0.0.42") do
      assert Links::NetworkWhitelist.includes?("10.0.0.42")
      assert_not Links::NetworkWhitelist.includes?("10.0.0.43")
    end
  end

  test "parses comma and whitespace separated entries" do
    with_network_whitelist("192.168.0.0/16, 10.0.0.0/8") do
      assert Links::NetworkWhitelist.includes?("192.168.1.1")
      assert Links::NetworkWhitelist.includes?("10.20.30.40")
      assert_not Links::NetworkWhitelist.includes?("172.16.0.1")
    end
  end

  test "ignores invalid entries" do
    with_network_whitelist("not-an-ip,192.168.0.0/16") do
      assert Links::NetworkWhitelist.includes?("192.168.1.1")
      assert_not Links::NetworkWhitelist.includes?("not-an-ip")
    end
  end

  test "rejects invalid ip addresses" do
    with_network_whitelist("192.168.0.0/16") do
      assert_not Links::NetworkWhitelist.includes?("not-an-ip")
      assert_not Links::NetworkWhitelist.includes?("")
    end
  end

  test "returns false when not configured" do
    with_network_whitelist(nil) do
      assert_not Links::NetworkWhitelist.includes?("192.168.1.1")
      assert_not Links::NetworkWhitelist.includes?("10.0.0.1")
    end
  end

  test "reset clears cached networks" do
    with_network_whitelist("192.168.0.0/16") do
      assert Links::NetworkWhitelist.includes?("192.168.1.1")

      ENV.delete("NETWORK_WHITELIST")
      Links::NetworkWhitelist.reset!

      assert_not Links::NetworkWhitelist.configured?
      assert_not Links::NetworkWhitelist.includes?("192.168.1.1")
    end
  end

  test "includes ip at cidr network boundary" do
    with_network_whitelist("192.168.0.0/16") do
      assert Links::NetworkWhitelist.includes?("192.168.0.0")
      assert Links::NetworkWhitelist.includes?("192.168.255.255")
      assert_not Links::NetworkWhitelist.includes?("192.169.0.0")
    end
  end
end
