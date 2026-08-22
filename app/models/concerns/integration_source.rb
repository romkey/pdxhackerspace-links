module IntegrationSource
  extend ActiveSupport::Concern

  SYNC_STATUSES = %w[running success partial failed].freeze

  included do
    validates :last_sync_status, inclusion: { in: SYNC_STATUSES }, allow_nil: true
  end

  def syncing?
    last_sync_status == "running"
  end

  def last_sync_ok?
    last_sync_status == "success"
  end

  def last_sync_failed?
    last_sync_status == "failed"
  end

  def record_sync!(status:, message:)
    update!(
      last_synced_at: Time.current,
      last_sync_status: status,
      last_sync_message: message
    )
  end
end
