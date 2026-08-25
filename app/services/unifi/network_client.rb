module Unifi
  # UniFi Network integration API: adopted infrastructure devices (gateways,
  # switches, access points) across every local site.
  class NetworkClient
    BASE_PATH = "/proxy/network/integration".freeze
    PAGE_LIMIT = 200
    MAX_PAGES = 50

    def self.for(unifi_controller, transport: nil, rate_limiter: nil)
      new(client: Client.new(
        host: unifi_controller.host,
        port: unifi_controller.port,
        api_key: unifi_controller.api_key,
        verify_tls: unifi_controller.verify_tls?,
        base_path: BASE_PATH,
        transport: transport,
        rate_limiter: rate_limiter
      ))
    end

    def initialize(client:)
      @client = client
    end

    def application_version
      @client.get("/v1/info")["applicationVersion"]
    end

    def sites
      paged("/v1/sites")
    end

    def devices(site_id:)
      paged("/v1/sites/#{ERB::Util.url_encode(site_id)}/devices")
    end

    def device_records
      sites.flat_map do |site|
        devices(site_id: site["id"]).map { |device| build_record(device, site) }
      end
    end

    private

    def paged(path)
      results = []
      offset = 0

      MAX_PAGES.times do
        page = @client.get(path, offset: offset, limit: PAGE_LIMIT)
        data = Array(page["data"])
        results.concat(data)
        offset += data.size

        break if data.empty? || offset >= page["totalCount"].to_i
      end

      results
    end

    def build_record(device, site)
      DeviceRecord.new(
        source: "network",
        external_id: device["id"],
        kind: kind_for(device),
        name: device["name"],
        model: device["model"],
        ieee_address: Integrations::HardwareAddress.normalize(device["macAddress"]),
        ip_address: device["ipAddress"],
        firmware_version: device["firmwareVersion"],
        state: device["state"],
        site_external_id: site["id"],
        site_name: site["name"],
        payload: device
      )
    end

    # A console can report several roles; the most specific one wins.
    def kind_for(device)
      features = Array(device["features"])
      return "gateway" if features.include?("gateway")
      return "switch" if features.include?("switching")
      return "access_point" if features.include?("accessPoint")

      "device"
    end
  end
end
