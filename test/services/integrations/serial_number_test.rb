require "test_helper"

class Integrations::SerialNumberTest < ActiveSupport::TestCase
  test "reads the camelCase key UniFi uses" do
    assert_equal "FCECDA123456", Integrations::SerialNumber.extract("serialNumber" => "FCECDA123456")
  end

  test "reads the snake_case and short spellings" do
    assert_equal "AAA111", Integrations::SerialNumber.extract("serial_number" => "AAA111")
    assert_equal "BBB222", Integrations::SerialNumber.extract("serialNo" => "BBB222")
    assert_equal "CCC333", Integrations::SerialNumber.extract("serial" => "CCC333")
  end

  test "prefers the most explicit key when a payload carries several" do
    payload = { "serial" => "LEGACY01", "serialNumber" => "FCECDA123456" }

    assert_equal "FCECDA123456", Integrations::SerialNumber.extract(payload)
  end

  test "strips surrounding whitespace" do
    assert_equal "FCECDA123456", Integrations::SerialNumber.extract("serial" => "  FCECDA123456 ")
  end

  test "coerces a numeric serial to a string" do
    assert_equal "123456", Integrations::SerialNumber.extract("serial" => 123456)
  end

  test "ignores placeholders vendors send instead of omitting the field" do
    assert_nil Integrations::SerialNumber.extract("serial" => "unknown")
    assert_nil Integrations::SerialNumber.extract("serial" => "N/A")
    assert_nil Integrations::SerialNumber.extract("serial" => "")
    assert_nil Integrations::SerialNumber.extract("serial" => "   ")
    assert_nil Integrations::SerialNumber.extract("serial" => "0")
  end

  test "ignores nested serials that belong to another component" do
    payload = { "storageInfo" => { "storageDrives" => [ { "serial" => "WD-DRIVE-1" } ] } }

    assert_nil Integrations::SerialNumber.extract(payload)
  end

  test "ignores values that are not scalar" do
    assert_nil Integrations::SerialNumber.extract("serial" => { "value" => "X1" })
    assert_nil Integrations::SerialNumber.extract("serial" => [ "X1" ])
    assert_nil Integrations::SerialNumber.extract("serial" => true)
  end

  test "returns nil for a payload without a serial" do
    assert_nil Integrations::SerialNumber.extract("model" => "U6-Lite")
    assert_nil Integrations::SerialNumber.extract({})
    assert_nil Integrations::SerialNumber.extract(nil)
  end
end
