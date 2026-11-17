module Metrics
  # Runs every collector and renders the scrape. A collector that raises is
  # reported through links_scrape_collector_success instead of failing the
  # whole scrape, so a Redis outage still leaves the database metrics readable.
  class Report
    COLLECTORS = {
      "app" => "Metrics::Collectors::App",
      "runtime" => "Metrics::Collectors::Runtime",
      "records" => "Metrics::Collectors::Records",
      "integrations" => "Metrics::Collectors::Integrations",
      "recorded" => "Metrics::Collectors::Recorded",
      "sidekiq" => "Metrics::Collectors::Sidekiq"
    }.freeze

    def self.render(collectors: COLLECTORS)
      new(collectors).render
    end

    def initialize(collectors)
      @collectors = collectors
    end

    def render
      out = Exposition.new
      success = {}
      durations = {}

      @collectors.each do |name, collector|
        started = clock
        success[{ collector: name }] = run(name, collector, out)
        durations[{ collector: name }] = clock - started
      end

      out.gauge("scrape_collector_success", "Whether the collector ran without error (1) or failed (0).", success)
      out.gauge("scrape_collector_duration_seconds", "Time the collector took during this scrape.", durations)
      out.to_s
    end

    private

    def run(name, collector, out)
      collector = collector.constantize if collector.is_a?(String)
      collector.call(out)
      true
    rescue StandardError => error
      Rails.logger.warn("Metrics collector #{name} failed: #{error.class}: #{error.message}")
      false
    end

    def clock
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
