module Unifi
  # UniFi Protect integration API: cameras and the rest of the Protect device
  # families. Unlike the Network API these endpoints are not site-scoped, return
  # bare arrays, and carry no IP address or firmware version.
  class ProtectClient
    BASE_PATH = "/proxy/protect/integration".freeze

    COLLECTIONS = {
      "cameras" => "camera",
      "lights" => "light",
      "sensors" => "sensor",
      "chimes" => "chime",
      "viewers" => "viewer",
      "speakers" => "speaker",
      "bridges" => "bridge",
      "fobs" => "fob",
      "sirens" => "siren",
      "relays" => "relay",
      "alarm-hubs" => "alarm_hub"
    }.freeze

    def self.for(unifi_controller, transport: nil)
      new(client: Client.new(
        host: unifi_controller.host,
        port: unifi_controller.port,
        api_key: unifi_controller.api_key,
        verify_tls: unifi_controller.verify_tls?,
        base_path: BASE_PATH,
        transport: transport
      ))
    end

    def initialize(client:)
      @client = client
    end

    def application_version
      @client.get("/v1/meta/info")["applicationVersion"]
    end

    def device_records
      collection_records + nvr_records
    end

    private

    def collection_records
      COLLECTIONS.flat_map do |path, kind|
        fetch_collection(path).map { |device| build_record(device, kind) }
      end
    end

    def nvr_records
      nvr = fetch("/v1/nvrs")
      return [] unless nvr.is_a?(Hash) && nvr["id"].present?

      [ build_record(nvr, "nvr") ]
    end

    # Older Protect releases do not expose every device family.
    def fetch_collection(path)
      Array(fetch("/v1/#{path}"))
    end

    def fetch(path)
      @client.get(path)
    rescue Client::NotFoundError
      nil
    end

    def build_record(device, kind)
      DeviceRecord.new(
        source: "protect",
        external_id: device["id"],
        kind: kind,
        name: device["name"],
        model: device["type"],
        mac_address: MacAddress.normalize(device["mac"]),
        state: device["state"],
        payload: device
      )
    end
  end
end
