module Zigbee2mqtt
  class TestConnection
    Result = Data.define(:success, :message) do
      def success?
        success
      end
    end

    def self.call(zigbee2mqtt_bridge:, client: nil)
      new(zigbee2mqtt_bridge: zigbee2mqtt_bridge, client: client).call
    end

    def initialize(zigbee2mqtt_bridge:, client: nil)
      @bridge = zigbee2mqtt_bridge
      @client = client
    end

    def call
      response = client.fetch
      count = Array(response.devices).size

      Result.new(
        success: true,
        message: "Connected to #{@bridge.mqtt_host}:#{@bridge.mqtt_port} — #{count} #{'device'.pluralize(count)} on #{@bridge.base_topic}/bridge/devices."
      )
    rescue Client::AuthenticationError => error
      Result.new(success: false, message: error.message)
    rescue Client::Error => error
      Result.new(success: false, message: error.message)
    end

    private

    def client
      @client ||= Client.for(@bridge)
    end
  end
end
