require "active_support/key_generator"
require "openssl"

module Links
  # Key material for Active Record encryption, used by the UniFi controller API key.
  #
  # Explicit environment variables win. Otherwise the keys are derived from
  # secret_key_base so a standard deployment needs no extra configuration.
  # Rotating SECRET_KEY_BASE without setting these variables makes existing
  # ciphertext unreadable.
  module EncryptionKeys
    KEY_LENGTH = 32

    module_function

    def primary_key
      ENV["ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY"].presence || derive("active record encryption primary key")
    end

    def deterministic_key
      ENV["ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY"].presence ||
        derive("active record encryption deterministic key")
    end

    def key_derivation_salt
      ENV["ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT"].presence ||
        derive("active record encryption key derivation salt")
    end

    def derive(label, secret: Rails.application.secret_key_base)
      ActiveSupport::KeyGenerator
        .new(secret, hash_digest_class: OpenSSL::Digest::SHA256)
        .generate_key(label, KEY_LENGTH)
        .unpack1("H*")
    end
  end
end
