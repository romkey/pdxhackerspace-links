require "test_helper"

class PrusaConnect::ImportTest < ActiveSupport::TestCase
  setup do
    @account = prusa_connect_accounts(:main)
    @account.prusa_connect_printers.destroy_all
  end

  class StubClient
    def initialize(records) = @records = records
    def printer_records = @records
  end

  class FailingClient
    def initialize(message) = @message = message
    def printer_records = raise(PrusaConnect::Client::Error, @message)
  end

  def printer_record(overrides = {})
    PrusaConnect::PrinterRecord.new(**{
      external_id: "752dc9b9-b5f9-4a59-b743-94efc18b60cb",
      name: "Rack MK4",
      printer_model: "MK4S",
      printer_type_name: "Original Prusa MK4S",
      serial_number: "CZPX12345678",
      firmware: "6.0.0+14778",
      ieee_address: "b8:27:eb:12:34:56",
      hostname: "mk4.local",
      location: "Rack 2",
      team_name: "Hackerspace",
      state: "IDLE",
      payload: { "uuid" => "752dc9b9-b5f9-4a59-b743-94efc18b60cb" }
    }.merge(overrides))
  end

  def import(records: [ printer_record ], account: @account)
    PrusaConnect::Import.call(
      prusa_connect_account: account,
      client: records.is_a?(Array) ? StubClient.new(records) : records
    )
  end

  test "imports printers and creates things" do
    result = nil

    assert_difference -> { PrusaConnectPrinter.count }, 1 do
      assert_difference -> { Thing.count }, 1 do
        result = import
      end
    end

    assert result.success?
    assert_equal 1, result.devices_created
    assert_equal 1, result.things_created
    assert_equal "success", result.status

    printer = @account.prusa_connect_printers.find_by(external_id: "752dc9b9-b5f9-4a59-b743-94efc18b60cb")
    assert_equal "Rack MK4", printer.name
    assert_equal "Rack MK4", printer.thing.name
    assert_equal "Prusa Research", printer.thing.manufacturer
  end

  test "links a printer to an existing thing by ieee address" do
    existing = things(:router)

    result = import(records: [ printer_record(ieee_address: existing.ieee_address) ])

    assert result.success?
    assert_equal 0, result.things_created
    assert_equal 1, result.things_linked

    printer = @account.prusa_connect_printers.find_by(external_id: "752dc9b9-b5f9-4a59-b743-94efc18b60cb")
    assert_equal existing, printer.thing
    assert_equal "unifi", existing.reload.integration_source
    assert_equal "Original Prusa MK4S", existing.model
  end

  test "is idempotent across runs" do
    import

    assert_no_difference -> { PrusaConnectPrinter.count } do
      result = import
      assert result.success?
      assert_equal 1, result.devices_updated
      assert_equal 0, result.devices_created
    end
  end

  test "archives printers that disappear from the account" do
    import
    printer = @account.prusa_connect_printers.first

    result = import(records: [])

    assert result.success?
    assert_equal 1, result.devices_archived
    assert_predicate printer.reload, :archived?
  end

  test "records a partial result when some printers fail validation" do
    result = import(records: [
      printer_record,
      printer_record(external_id: "", name: "Broken")
    ])

    assert_not result.success?
    assert_equal "partial", result.status
    assert_equal 1, result.devices_created
    assert_match "Broken", result.summary
  end

  test "records a failed sync when the client raises" do
    result = import(records: FailingClient.new("Timed out"))

    assert_not result.success?
    assert_equal "failed", result.status
    assert_match "Timed out", @account.reload.last_sync_message
  end
end
