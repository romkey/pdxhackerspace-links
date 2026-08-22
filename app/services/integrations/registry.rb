module Integrations
  class Registry
    Entry = Data.define(:key, :label, :settings_path, :controller_path)

    def self.all
      @all ||= [
        Entry.new(
          key: "unifi",
          label: "UniFi",
          settings_path: :settings_unifi_controllers_path,
          controller_path: "settings/unifi_controllers"
        ),
        Entry.new(
          key: "zigbee2mqtt",
          label: "Zigbee2MQTT",
          settings_path: :settings_zigbee2mqtt_bridges_path,
          controller_path: "settings/zigbee2mqtt_bridges"
        )
      ].freeze
    end

    FILTER_NONE = "none".freeze

    def self.find(key)
      all.find { |entry| entry.key == key.to_s }
    end

    def self.keys
      all.map(&:key)
    end

    def self.filter_keys
      keys + [ FILTER_NONE ]
    end

    def self.label_for(key)
      return "None" if key.to_s == FILTER_NONE

      find(key)&.label || key.to_s.humanize
    end
  end
end
