require "test_helper"

class PrusaConnect::PrinterRecordTest < ActiveSupport::TestCase
  test "normalizes printer payloads into record attributes" do
    record = PrusaConnect::PrinterRecord.from_payload(
      "uuid" => "752dc9b9-b5f9-4a59-b743-94efc18b60cb",
      "name" => "Rack MK4",
      "printer_model" => "MK4S",
      "printer_type_name" => "Original Prusa MK4S",
      "sn" => "CZPX12345678",
      "firmware_version" => "6.0.0+14778",
      "printer_state" => "IDLE",
      "location" => "Rack 2",
      "team_name" => "Hackerspace",
      "network_info" => {
        "mac" => "94:2A:6F:26:C6:CA",
        "hostname" => "mk4.local"
      }
    )

    assert_equal "752dc9b9-b5f9-4a59-b743-94efc18b60cb", record.external_id
    assert_equal "94:2a:6f:26:c6:ca", record.ieee_address
    assert_equal "mk4.local", record.hostname
    assert_equal "6.0.0+14778", record.firmware
  end

  test "falls back to lan_mac when mac is missing" do
    record = PrusaConnect::PrinterRecord.from_payload(
      "uuid" => "11111111-1111-4111-8111-111111111111",
      "network_info" => { "lan_mac" => "d0:21:f9:8b:6a:ed" }
    )

    assert_equal "d0:21:f9:8b:6a:ed", record.ieee_address
  end
end
