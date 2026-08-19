require_relative "boot"

require "rails/all"
require_relative "../lib/app_host"
require_relative "../lib/links/encryption_keys"
require_relative "../lib/short_url"
require_relative "../lib/thing_tracking"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Links
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Thing photos are served without variants; skip vips/ImageMagick at boot.
    config.active_storage.variant_processor = :disabled

    # Encrypts the UniFi controller API key at rest.
    config.active_record.encryption.primary_key = Links::EncryptionKeys.primary_key
    config.active_record.encryption.deterministic_key = Links::EncryptionKeys.deterministic_key
    config.active_record.encryption.key_derivation_salt = Links::EncryptionKeys.key_derivation_salt

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
