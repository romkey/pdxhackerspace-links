module Zigbee2mqtt
  class ImportJob < ApplicationJob
    queue_as :default

    discard_on ActiveJob::DeserializationError

    def perform(zigbee2mqtt_bridge_id)
      bridge = Zigbee2mqttBridge.find_by(id: zigbee2mqtt_bridge_id)
      return if bridge.nil?
      return record_skip(bridge) unless bridge.enabled?

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

    private

    # A bridge can be disabled between an import being queued and the job
    # running it. Leaving the queued marker in place reports an import that will
    # never finish, and a disabled bridge offers no way to clear it. Only the
    # marker is cleared, so an earlier result is left intact.
    def record_skip(bridge)
      return unless bridge.syncing?

      bridge.update_columns(
        last_sync_status: "skipped",
        last_sync_message: "Import skipped because the bridge is disabled.",
        updated_at: Time.current
      )
    end
  end
end
