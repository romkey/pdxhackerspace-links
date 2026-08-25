module Unifi
  class ImportJob < ApplicationJob
    queue_as :default

    discard_on ActiveJob::DeserializationError

    def perform(unifi_controller_id)
      unifi_controller = UnifiController.find_by(id: unifi_controller_id)
      return if unifi_controller.nil?
      return record_skip(unifi_controller) unless unifi_controller.enabled?

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

    private

    # A controller can be disabled between an import being queued and the job
    # running it. Leaving the queued marker in place reports an import that will
    # never finish, and a disabled controller offers no way to clear it. Only the
    # marker is cleared, so an earlier result is left intact.
    def record_skip(unifi_controller)
      return unless unifi_controller.syncing?

      unifi_controller.update_columns(
        last_sync_status: "skipped",
        last_sync_message: "Import skipped because the controller is disabled.",
        updated_at: Time.current
      )
    end
  end
end
