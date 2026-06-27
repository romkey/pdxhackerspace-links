module Links
  module SentryConfig
    module_function

    def enabled?
      ENV["SENTRY_DSN"].present?
    end

    def configure!
      return unless enabled?

      ::Sentry.init do |config|
        config.dsn = ENV["SENTRY_DSN"]
        config.environment = environment_name
        config.release = release_name
        config.breadcrumbs_logger = %i[active_support_logger http_logger]
        config.send_default_pii = false
        config.enabled_environments = %w[production staging]
        config.traces_sample_rate = traces_sample_rate if traces_sample_rate.positive?
        config.excluded_exceptions += [ "ActionController::RoutingError" ]
      end
    end

    def environment_name
      ENV.fetch("SENTRY_ENVIRONMENT", Rails.env)
    end

    def release_name
      ENV["APP_VERSION"].presence
    end

    def traces_sample_rate
      ENV.fetch("SENTRY_TRACES_SAMPLE_RATE", "0").to_f
    end
  end
end
