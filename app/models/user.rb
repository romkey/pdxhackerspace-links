class User < ApplicationRecord
  has_secure_password validations: false

  validates :email, presence: true, uniqueness: { case_sensitive: false }
  validates :name, presence: true
  validates :password, presence: true, if: :local_account?
  validates :provider, :uid, presence: true, unless: :local_account?

  normalizes :email, with: ->(email) { email.strip.downcase }

  def local_account?
    provider.blank?
  end

  def self.from_omniauth(auth)
    find_or_initialize_by(provider: auth.provider, uid: auth.uid).tap do |user|
      user.email = auth.info.email
      user.name = auth.info.name.presence || auth.info.email.split("@").first
      user.save!
    end
  end

  def self.authenticate_local(email:, password:)
    return unless local_auth_configured?

    user = find_by(email: email.strip.downcase, provider: nil, uid: nil)
    user if user&.authenticate(password)
  end

  def self.local_auth_configured?
    ENV["LOCAL_AUTH_EMAIL"].present? && ENV["LOCAL_AUTH_PASSWORD"].present?
  end

  def self.ensure_local_account!
    return unless local_auth_configured?

    find_or_initialize_by(email: ENV.fetch("LOCAL_AUTH_EMAIL").strip.downcase).tap do |user|
      user.name = ENV.fetch("LOCAL_AUTH_NAME", "Local Admin")
      user.password = ENV.fetch("LOCAL_AUTH_PASSWORD")
      user.provider = nil
      user.uid = nil
      user.save!
    end
  end
end
