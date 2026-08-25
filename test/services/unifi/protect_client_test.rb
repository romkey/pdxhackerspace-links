require "test_helper"

class Unifi::ProtectClientTest < ActiveSupport::TestCase
  # Every Protect collection answers with an empty array unless the test says otherwise.
  def build_client(overrides = {}, nvr: nil)
    responses = Unifi::ProtectClient::COLLECTIONS.keys.index_with { [ 200, [] ] }
                                                 .transform_keys { |path| "/proxy/protect/integration/v1/#{path}" }
    responses["/proxy/protect/integration/v1/nvrs"] = [ 200, nvr || {} ]
    responses.merge!(overrides.transform_keys { |path| "/proxy/protect/integration/v1#{path}" })

    Unifi::ProtectClient.for(unifi_controllers(:udm), transport: unifi_transport(responses))
  end

  def camera(overrides = {})
    {
      "id" => "camera-1",
      "name" => "Front door",
      "mac" => "24A43C3DFEB9",
      "modelKey" => "camera",
      "type" => "G4 Doorbell",
      "state" => "CONNECTED"
    }.merge(overrides)
  end

  test "reads the application version" do
    client = build_client({ "/meta/info" => [ 200, { "applicationVersion" => "7.2.105" } ] })

    assert_equal "7.2.105", client.application_version
  end

  test "builds a device record for a camera" do
    client = build_client({ "/cameras" => [ 200, [ camera ] ] })

    record = client.device_records.sole

    assert_equal "protect", record.source
    assert_equal "camera-1", record.external_id
    assert_equal "camera", record.kind
    assert_equal "Front door", record.name
    assert_equal "G4 Doorbell", record.model
    assert_equal "24:a4:3c:3d:fe:b9", record.ieee_address
    assert_equal "CONNECTED", record.state
    assert_nil record.ip_address
  end

  test "imports every Protect device family" do
    client = build_client({
      "/cameras" => [ 200, [ camera ] ],
      "/sensors" => [ 200, [ { "id" => "sensor-1", "name" => "Door", "mac" => "AABBCCDDEEFF" } ] ],
      "/lights" => [ 200, [ { "id" => "light-1", "name" => "Yard", "mac" => "AABBCCDDEE01" } ] ]
    })

    assert_equal %w[camera light sensor], client.device_records.map(&:kind).sort
  end

  test "includes the NVR" do
    client = build_client(nvr: { "id" => "nvr-1", "name" => "UNVR", "mac" => "AABBCCDDEE02", "type" => "UNVR" })

    record = client.device_records.sole

    assert_equal "nvr", record.kind
    assert_equal "UNVR", record.name
  end

  test "skips device families the Protect version does not expose" do
    client = build_client({ "/fobs" => [ 404, {} ], "/cameras" => [ 200, [ camera ] ] })

    assert_equal [ "camera" ], client.device_records.map(&:kind)
  end

  test "returns nothing when the console has no Protect devices" do
    assert_empty build_client.device_records
  end
end
