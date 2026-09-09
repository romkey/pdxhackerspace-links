module PrusaConnect
  class ImportJob < ApplicationJob
    queue_as :default

    discard_on ActiveJob::DeserializationError

    def perform(prusa_connect_account_id)
      prusa_connect_account = PrusaConnectAccount.find_by(id: prusa_connect_account_id)
      return if prusa_connect_account.nil?
      return record_skip(prusa_connect_account) unless prusa_connect_account.enabled?

      Import.call(prusa_connect_account: prusa_connect_account)
    rescue StandardError => error
      prusa_connect_account&.update_columns(
        last_synced_at: Time.current,
        last_sync_status: "failed",
        last_sync_message: error.message,
        updated_at: Time.current
      )
      raise
    end

    private

    def record_skip(prusa_connect_account)
      return unless prusa_connect_account.syncing?

      prusa_connect_account.update_columns(
        last_sync_status: "skipped",
        last_sync_message: "Import skipped because the account is disabled.",
        updated_at: Time.current
      )
    end
  end
end
