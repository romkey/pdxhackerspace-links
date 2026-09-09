require "test_helper"

class PrusaConnectPrinterTest < ActiveSupport::TestCase
  test "maps desired thing attributes from printer fields" do
    printer = prusa_connect_printers(:mk4)

    assert_equal(
      {
        "name" => "Rack MK4",
        "ieee_address" => "94:2a:6f:26:c6:ca",
        "hostname" => "mk4.local",
        "model" => "Original Prusa MK4S",
        "serial_number" => "CZPX12345678",
        "manufacturer" => "Prusa Research",
        "manufacturer_url" => "https://www.prusa3d.com/"
      },
      printer.desired_thing_attributes
    )
  end

  test "external ids are unique per account" do
    duplicate = PrusaConnectPrinter.new(
      prusa_connect_account: prusa_connect_accounts(:main),
      external_id: prusa_connect_printers(:mk4).external_id,
      first_seen_at: Time.current,
      last_seen_at: Time.current
    )

    assert_not duplicate.valid?
  end
end
