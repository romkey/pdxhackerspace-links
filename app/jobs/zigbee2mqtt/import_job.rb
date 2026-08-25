module Zigbee2mqtt
  class ImportJob < ApplicationJob
    queue_as :default

    discard_on ActiveJob::DeserializationError

    def perform(zigbee2mqtt_bridge_id)
      bridge = Zigbee2mqttBridge.find_by(id: zigbee2mqtt_bridge_id)
      return if bridge.nil? || !bridge.enabled?

      Import.call(zigbee2mqtt_bridge: bridge)
    rescue StandardError => error
      bridge&.update_columns(
        last_synced_at: Time.current,
        last_sync_status: "failed",
        last_sync_message: error.message,
        updated_at: Time.current
      )
      raise
    end
  end
end
