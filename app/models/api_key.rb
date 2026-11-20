# A bearer token for the read-only JSON API. Keys never expire; deleting one
# revokes it. Only a SHA-256 digest of the token is stored, so the token itself
# is shown once, when the key is created.
class ApiKey < ApplicationRecord
  TOKEN_PREFIX = "links_".freeze
  PREFIX_LENGTH = TOKEN_PREFIX.length + 6
  LAST_USED_RESOLUTION = 1.minute

  belongs_to :user, optional: true

  attr_reader :token

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :token_digest, presence: true, uniqueness: true
  validates :token_prefix, presence: true

  normalizes :name, with: ->(name) { name.strip }

  scope :ordered, -> { order(Arel.sql("LOWER(api_keys.name)")) }

  def self.generate(name:, user: nil)
    token = "#{TOKEN_PREFIX}#{SecureRandom.base58(40)}"
    new(name: name, user: user, token_digest: digest(token), token_prefix: token.first(PREFIX_LENGTH)).tap do |key|
      key.instance_variable_set(:@token, token)
    end
  end

  def self.authenticate(token)
    return if token.blank?

    find_by(token_digest: digest(token))&.tap(&:record_use!)
  end

  def self.digest(token)
    OpenSSL::Digest::SHA256.hexdigest(token.to_s)
  end

  def record_use!(at = Time.current)
    return if last_used_at && last_used_at > at - LAST_USED_RESOLUTION

    update_column(:last_used_at, at)
  end
end
