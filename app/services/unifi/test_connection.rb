module Unifi
  # Probes the version endpoint of each enabled application so a misconfigured
  # host, API key, or TLS setting is reported before an import is attempted.
  class TestConnection
    Result = Data.define(:versions, :errors) do
      def success?
        errors.empty? && versions.any?
      end

      def message
        reachable = versions.map { |application, version| "#{application} #{version}" }
        [ ("Connected to #{reachable.to_sentence}" if reachable.any?), errors.join("; ").presence ]
          .compact.join(" — ")
          .presence || "No UniFi applications are enabled for this controller."
      end
    end

    def self.call(unifi_controller:, network_client: nil, protect_client: nil)
      new(unifi_controller: unifi_controller, network_client: network_client, protect_client: protect_client).call
    end

    def initialize(unifi_controller:, network_client: nil, protect_client: nil)
      @unifi_controller = unifi_controller
      @network_client = network_client
      @protect_client = protect_client
      @versions = {}
      @errors = []
    end

    def call
      probe("Network") { (@network_client || unifi_controller.network_client).application_version } if
        unifi_controller.network_enabled?
      probe("Protect") { (@protect_client || unifi_controller.protect_client).application_version } if
        unifi_controller.protect_enabled?

      Result.new(versions: @versions, errors: @errors)
    end

    private

    attr_reader :unifi_controller

    def probe(application)
      @versions[application] = yield.presence || "(unknown version)"
    rescue Client::Error => error
      @errors << "#{application}: #{error.message}"
    end
  end
end
