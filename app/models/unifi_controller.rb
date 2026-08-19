class UnifiController < ApplicationRecord
  HOST_FORMAT = /\A[a-z0-9]([a-z0-9\-.]*[a-z0-9])?\z/
  SYNC_STATUSES = %w[running success partial failed].freeze

  encrypts :api_key

  has_many :unifi_devices, dependent: :destroy
  has_many :things, -> { distinct }, through: :unifi_devices

  validates :name, presence: true, uniqueness: true
  validates :host, presence: true, format: { with: HOST_FORMAT }, uniqueness: { scope: :port }
  validates :port, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 65_535 }
  validates :api_key, presence: true
  validates :last_sync_status, inclusion: { in: SYNC_STATUSES }, allow_nil: true
  validate :at_least_one_application_enabled

  normalizes :name, with: ->(value) { value.to_s.strip }
  normalizes :host, with: ->(value) { normalize_host(value) }

  scope :enabled, -> { where(enabled: true) }
  scope :ordered, -> { order(:name) }

  def self.normalize_host(value)
    value.to_s.strip.downcase.sub(%r{\Ahttps?://}, "").sub(%r{[/:].*\z}, "")
  end

  def base_url
    port == 443 ? "https://#{host}" : "https://#{host}:#{port}"
  end

  def network_client(transport: nil)
    Unifi::NetworkClient.for(self, transport: transport, rate_limiter: rate_limiter)
  end

  def protect_client(transport: nil)
    Unifi::ProtectClient.for(self, transport: transport, rate_limiter: rate_limiter)
  end

  # Both applications are proxied by the same console and share its request
  # budget, so they have to be paced together rather than per client.
  def rate_limiter
    @rate_limiter ||= Unifi::RateLimiter.new
  end

  def enabled_applications
    applications = []
    applications << "network" if network_enabled?
    applications << "protect" if protect_enabled?
    applications
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

  def device_count
    unifi_devices.active.count
  end

  private

  def at_least_one_application_enabled
    return if network_enabled? || protect_enabled?

    errors.add(:base, "Enable the Network API, the Protect API, or both")
  end
end
