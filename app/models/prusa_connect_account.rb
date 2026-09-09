class PrusaConnectAccount < ApplicationRecord
  include IntegrationSource

  encrypts :refresh_token
  encrypts :access_token

  has_many :prusa_connect_printers, dependent: :destroy
  has_many :things, -> { distinct }, through: :prusa_connect_printers

  validates :name, presence: true, uniqueness: true
  validates :refresh_token, presence: true

  normalizes :name, with: ->(value) { value.to_s.strip }

  scope :enabled, -> { where(enabled: true) }
  scope :ordered, -> { order(:name) }

  def client(transport: nil)
    PrusaConnect::Client.for(self, transport: transport)
  end

  def printer_count
    prusa_connect_printers.active.count
  end

  def access_token_valid?
    access_token.present? && access_token_expires_at.present? &&
      access_token_expires_at > PrusaConnect::AccessToken::EXPIRY_SKEW.from_now
  end
end
