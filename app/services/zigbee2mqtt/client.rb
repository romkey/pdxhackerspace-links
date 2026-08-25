require "json"
require "mqtt"

module Zigbee2mqtt
  class Client
    class Error < StandardError; end
    class ConnectionError < Error; end
    class AuthenticationError < Error; end
    class TimeoutError < Error; end

    STATE_WINDOW_SECONDS = 2
    CONNECT_TIMEOUT = 10

    Response = Data.define(:devices, :last_seen)

    def self.for(bridge, transport: nil)
      new(bridge: bridge, transport: transport)
    end

    def initialize(bridge:, transport: nil)
      @bridge = bridge
      @transport = transport
    end

    def device_records
      response = fetch
      Array(response.devices).map { |device| build_record(device, response.last_seen) }
    end

    def fetch
      transport.call
    end

    private

    attr_reader :bridge

    def transport
      @transport ||= method(:fetch_over_mqtt)
    end

    def fetch_over_mqtt
      devices = nil
      last_seen = {}
      name_to_ieee = {}
      devices_received_at = nil
      client = nil

      client = connect
      client.subscribe(devices_topic)
      client.subscribe("#{base_topic}/#")

      deadline = Time.current + CONNECT_TIMEOUT

      client.get do |topic, message|
        if topic == devices_topic
          devices = parse_devices(message)
          build_name_map(devices, name_to_ieee)
          devices_received_at ||= Time.current
          deadline = devices_received_at + STATE_WINDOW_SECONDS
        else
          capture_last_seen(topic, message, last_seen, name_to_ieee)
        end

        break if devices && Time.current >= deadline
        raise TimeoutError, "Timed out waiting for #{devices_topic}" if Time.current >= deadline && devices.nil?
      end

      Response.new(devices: devices || [], last_seen: last_seen)
    rescue MQTT::ProtocolException, MQTT::NotConnectedException => error
      raise ConnectionError, "MQTT connection failed: #{error.message}"
    ensure
      client&.disconnect
    end

    def connect
      MQTT::Client.connect(
        host: bridge.mqtt_host,
        port: bridge.mqtt_port,
        username: bridge.mqtt_username.presence,
        password: bridge.mqtt_password.presence,
        ssl: bridge.mqtt_tls?,
        keep_alive: 30
      )
    rescue MQTT::Exception => error
      message = error.message
      raise AuthenticationError, message if message.match?(/auth|password|username/i)

      raise ConnectionError, "Cannot connect to #{bridge.mqtt_host}:#{bridge.mqtt_port} (#{message})"
    end

    def devices_topic
      "#{base_topic}/bridge/devices"
    end

    def base_topic
      bridge.base_topic.presence || "zigbee2mqtt"
    end

    def parse_devices(message)
      JSON.parse(message.to_s)
    rescue JSON::ParserError => error
      raise Error, "Invalid JSON on #{devices_topic}: #{error.message}"
    end

    def build_name_map(devices, name_to_ieee)
      Array(devices).each do |device|
        ieee = Integrations::HardwareAddress.normalize(device["ieee_address"])
        next if ieee.blank?

        name_to_ieee[device["friendly_name"]] = ieee if device["friendly_name"].present?
      end
    end

    def capture_last_seen(topic, message, last_seen, name_to_ieee)
      return unless topic.start_with?("#{base_topic}/") && !topic.start_with?("#{base_topic}/bridge/")

      friendly_name = topic.delete_prefix("#{base_topic}/")
      return if friendly_name.blank?

      payload = JSON.parse(message.to_s)
      timestamp = payload["last_seen"]
      return if timestamp.blank?

      parsed = parse_last_seen(timestamp)
      return unless parsed

      ieee = Integrations::HardwareAddress.normalize(payload["ieee_address"])
      ieee ||= name_to_ieee[friendly_name]
      last_seen[ieee] = parsed if ieee
    rescue JSON::ParserError
      nil
    end

    def parse_last_seen(value)
      case value
      when Numeric
        Time.zone.at(value / 1000.0)
      when String
        Time.zone.parse(value)
      end
    rescue ArgumentError, TypeError
      nil
    end

    def build_record(device, last_seen_map)
      ieee = Integrations::HardwareAddress.normalize(device["ieee_address"])
      definition = device["definition"] || {}
      model = definition["model"].presence || device["model_id"].presence
      manufacturer = definition["vendor"].presence || device["manufacturer"].presence
      reported_last_seen = last_seen_map[ieee]

      DeviceRecord.new(
        ieee_address: ieee,
        friendly_name: device["friendly_name"],
        device_type: device["type"],
        network_address: device["network_address"],
        manufacturer: manufacturer,
        model: model,
        model_description: definition["description"],
        power_source: device["power_source"],
        software_build_id: device["software_build_id"],
        date_code: device["date_code"],
        supported: device.fetch("supported", true),
        disabled: device.fetch("disabled", false),
        reported_last_seen_at: reported_last_seen,
        payload: device
      )
    end
  end
end
