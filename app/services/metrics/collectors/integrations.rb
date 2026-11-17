module Metrics
  module Collectors
    # The servers Links imports from (UniFi consoles, Zigbee2MQTT bridges,
    # Prusa Connect accounts), how their last import went, and what they hold.
    module Integrations
      Source = Data.define(:integration, :source_class, :device_class, :foreign_key)

      SOURCES = [
        Source.new("unifi", "UnifiController", "UnifiDevice", :unifi_controller_id),
        Source.new("zigbee2mqtt", "Zigbee2mqttBridge", "Zigbee2mqttDevice", :zigbee2mqtt_bridge_id),
        Source.new("prusa_connect", "PrusaConnectAccount", "PrusaConnectPrinter", :prusa_connect_account_id)
      ].freeze

      DEVICE_STATES = {
        "archived" => "archived_at IS NOT NULL",
        "ignored" => "archived_at IS NULL AND ignored",
        "linked" => "archived_at IS NULL AND NOT ignored AND thing_id IS NOT NULL",
        "unlinked" => "archived_at IS NULL AND NOT ignored AND thing_id IS NULL"
      }.freeze

      module_function

      def call(out)
        enabled = {}
        synced_at = {}
        status = {}
        devices = {}

        SOURCES.each do |source|
          names = {}
          source.source_class.constantize.find_each do |record|
            labels = { integration: source.integration, source: record.name }
            names[record.id] = record.name
            enabled[labels] = record.enabled?
            synced_at[labels] = record.last_synced_at&.to_f
            IntegrationSource::SYNC_STATUSES.each do |name|
              status[labels.merge(status: name)] = record.last_sync_status == name
            end
          end
          devices.merge!(device_counts(source, names))
        end

        out.gauge("integration_source_enabled", "Whether imports from this source are enabled.", enabled)
        out.gauge("integration_source_last_sync_timestamp_seconds", "When this source was last imported.", synced_at)
        out.gauge("integration_source_last_sync_status",
                  "Result of the last import; 1 on the series for the current status.", status)
        out.gauge("integration_devices",
                  "Imported devices by source and state (linked to a thing, unlinked, ignored, or archived).", devices)
        unifi_hosts(out)
      end

      def device_counts(source, names)
        columns = DEVICE_STATES.values.map { |condition| Arel.sql("COUNT(*) FILTER (WHERE #{condition})") }
        rows = source.device_class.constantize.group(source.foreign_key).pluck(source.foreign_key, *columns)

        rows.each_with_object({}) do |(source_id, *counts), result|
          DEVICE_STATES.keys.zip(counts) do |state, count|
            labels = { integration: source.integration, source: names[source_id].to_s, state: state }
            result[labels] = count
          end
        end
      end

      def unifi_hosts(out)
        names = UnifiController.pluck(:id, :name).to_h
        counts = UnifiHost.where(archived_at: nil).group(:unifi_controller_id, :connection_type, :online).count
        out.gauge("unifi_hosts", "Network clients known to a UniFi console, by connection type and whether online.",
                  counts.to_h do |(controller_id, connection, online), count|
                    [ { source: names[controller_id].to_s, connection: connection.presence || "unknown", online: online }, count ]
                  end)
      end
    end
  end
end
