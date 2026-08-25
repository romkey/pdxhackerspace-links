module Unifi
  class ImportJob < ApplicationJob
    queue_as :default

    discard_on ActiveJob::DeserializationError

    def perform(unifi_controller_id)
      unifi_controller = UnifiController.find_by(id: unifi_controller_id)
      return if unifi_controller.nil? || !unifi_controller.enabled?

      Import.call(unifi_controller: unifi_controller)
    rescue StandardError => error
      unifi_controller&.update_columns(
        last_synced_at: Time.current,
        last_sync_status: "failed",
        last_sync_message: error.message,
        updated_at: Time.current
      )
      raise
    end
  end
end
