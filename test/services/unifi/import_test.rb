require "test_helper"

class Unifi::ImportTest < ActiveSupport::TestCase
  setup do
    @unifi_controller = unifi_controllers(:udm)
    @unifi_controller.unifi_devices.destroy_all
  end

  # Stand-in clients keep the import test focused on upsert, linking, and archiving.
  class StubClient
    def initialize(records) = @records = records
    def device_records = @records
  end

  class FailingClient
    def initialize(message) = @message = message
    def device_records = raise(Unifi::Client::Error, @message)
  end

  def network_record(overrides = {})
    Unifi::DeviceRecord.new(**{
      source: "network",
      external_id: "network-1",
      kind: "switch",
      name: "Rack switch",
      model: "USW-24-PoE",
      mac_address: "aa:bb:cc:dd:ee:01",
      ip_address: "192.168.1.5",
      firmware_version: "6.6.55",
      state: "ONLINE",
      site_external_id: "site-1",
      site_name: "Default",
      payload: { "id" => "network-1" }
    }.merge(overrides))
  end

  def protect_record(overrides = {})
    Unifi::DeviceRecord.new(**{
      source: "protect",
      external_id: "protect-1",
      kind: "camera",
      name: "Front door",
      model: "G4 Doorbell",
      mac_address: "aa:bb:cc:dd:ee:02",
      state: "CONNECTED",
      payload: { "id" => "protect-1" }
    }.merge(overrides))
  end

  def import(network: [ network_record ], protect: [ protect_record ], unifi_controller: @unifi_controller)
    Unifi::Import.call(
      unifi_controller: unifi_controller,
      network_client: network.is_a?(Array) ? StubClient.new(network) : network,
      protect_client: protect.is_a?(Array) ? StubClient.new(protect) : protect
    )
  end

  test "imports devices from both applications and creates things" do
    result = nil

    assert_difference -> { UnifiDevice.count }, 2 do
      assert_difference -> { Thing.count }, 2 do
        result = import
      end
    end

    assert result.success?
    assert_equal 2, result.devices_created
    assert_equal 2, result.things_created
    assert_equal "success", result.status

    device = @unifi_controller.unifi_devices.find_by(external_id: "network-1")
    assert_equal "switch", device.kind
    assert_equal "192.168.1.5", device.ip_address
    assert_equal "Rack switch", device.thing.name
    assert_equal({ "id" => "network-1" }, device.payload)
  end

  test "is idempotent across runs" do
    import

    assert_no_difference [ -> { UnifiDevice.count }, -> { Thing.count } ] do
      result = import
      assert_equal 0, result.devices_created
      assert_equal 2, result.devices_updated
      assert_equal 0, result.things_created
    end
  end

  test "picks up changes from the controller" do
    import
    import(network: [ network_record(name: "Rack switch A", ip_address: "192.168.1.6") ])

    device = @unifi_controller.unifi_devices.find_by(external_id: "network-1")
    assert_equal "Rack switch A", device.name
    assert_equal "192.168.1.6", device.thing.ip_address
  end

  test "archives devices that disappear from the controller" do
    import
    result = import(network: [], protect: [ protect_record ])

    assert_equal 1, result.devices_archived
    device = @unifi_controller.unifi_devices.find_by(external_id: "network-1")
    assert device.archived?
    assert_not_nil device.thing, "archiving a device keeps its thing"
  end

  test "restores a device that comes back" do
    import
    import(network: [])
    import

    assert_not @unifi_controller.unifi_devices.find_by(external_id: "network-1").archived?
  end

  test "keeps one application's inventory when the other fails" do
    import
    result = import(network: FailingClient.new("Cannot reach unifi.example.com:443"))

    assert_not result.success?
    assert_equal "partial", result.status
    assert_match "Network: Cannot reach", result.errors.sole
    assert_not @unifi_controller.unifi_devices.find_by(external_id: "network-1").archived?,
               "a failed fetch must not archive devices"
  end

  test "reports a failure when nothing could be imported" do
    result = import(
      network: FailingClient.new("Cannot reach console"),
      protect: FailingClient.new("Cannot reach console")
    )

    assert_equal "failed", result.status
    assert_equal 2, result.errors.size
  end

  test "skips an application the controller has turned off" do
    @unifi_controller.update!(protect_enabled: false)

    result = import(protect: FailingClient.new("should not be called"))

    assert result.success?
    assert_equal 1, result.devices_created
  end

  test "does not create things when the controller has auto create off" do
    @unifi_controller.update!(auto_create_things: false)

    assert_no_difference -> { Thing.count } do
      result = import
      assert_equal 0, result.things_created
    end

    assert_nil @unifi_controller.unifi_devices.find_by(external_id: "network-1").thing
  end

  test "links a device to an existing thing with the same MAC" do
    existing = Thing.create!(name: "Rack switch", mac_address: "aa:bb:cc:dd:ee:01")

    result = import(protect: [])

    assert_equal 1, result.things_linked
    assert_equal 0, result.things_created
    assert_equal existing, @unifi_controller.unifi_devices.find_by(external_id: "network-1").thing
  end

  test "leaves ignored devices unlinked" do
    import
    device = @unifi_controller.unifi_devices.find_by(external_id: "network-1")
    device.thing.destroy!

    assert_no_difference -> { Thing.count } do
      import
    end

    assert device.reload.ignored?
    assert_nil device.thing
  end

  test "records a device that cannot be synced without aborting the import" do
    Thing.create!(name: "Conflicting", mac_address: "aa:bb:cc:dd:ee:02")
    import
    # Point the network device at the MAC already held by the camera's thing.
    result = import(network: [ network_record(mac_address: "aa:bb:cc:dd:ee:02") ])

    assert_not result.success?
    assert_equal 1, result.errors.size
    assert_equal 1, @unifi_controller.unifi_devices.where(source: "network").active.count,
                 "the failing device must not be archived"
  end

  test "stamps the controller with the outcome" do
    freeze_time do
      import

      @unifi_controller.reload
      assert_equal Time.current, @unifi_controller.last_synced_at
      assert_equal "success", @unifi_controller.last_sync_status
      assert_match "2 devices", @unifi_controller.last_sync_message
    end
  end
end
