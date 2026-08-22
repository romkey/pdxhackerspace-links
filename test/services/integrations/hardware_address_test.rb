require "test_helper"

class Integrations::HardwareAddressTest < ActiveSupport::TestCase
  test "normalizes EUI-48 from dashed input" do
    assert_equal "94:2a:6f:26:c6:ca", Integrations::HardwareAddress.normalize("94-2A-6F-26-C6-CA")
  end

  test "normalizes EUI-64 from 0x prefix input" do
    assert_equal "90:fd:9f:ff:fe:64:94:fc", Integrations::HardwareAddress.normalize("0x90fd9ffffe6494fc")
  end

  test "rejects invalid lengths" do
    assert_nil Integrations::HardwareAddress.normalize("94:2a:6f")
    assert_nil Integrations::HardwareAddress.normalize("0x1234")
  end

  test "displays EUI-64 in 0x form" do
    assert_equal "0x90fd9ffffe6494fc", Integrations::HardwareAddress.display("90:fd:9f:ff:fe:64:94:fc")
  end

  test "displays EUI-48 in colon form" do
    assert_equal "94:2a:6f:26:c6:ca", Integrations::HardwareAddress.display("94:2a:6f:26:c6:ca")
  end
end
