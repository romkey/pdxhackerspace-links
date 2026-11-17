require "socket"

module Metrics
  module Collectors
    module App
      module_function

      def call(out)
        out.gauge("app_info", "Running version of Links; the value is always 1.", {
          {
            version: Links::Version.current,
            ruby_version: RUBY_VERSION,
            rails_version: Rails.version,
            environment: Rails.env,
            hostname: Socket.gethostname
          } => 1
        })
        out.gauge("web_process_start_time_seconds", "When the web process answering this scrape booted.",
                  Metrics.booted_at.to_f)
      end
    end
  end
end
