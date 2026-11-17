# Prometheus metrics for the /metrics endpoint. Everything is off until
# METRICS_TOKEN is set: the endpoint answers 404 and nothing is recorded.
module Metrics
  PREFIX = "links".freeze

  module_function

  def token
    ENV["METRICS_TOKEN"].presence
  end

  def enabled?
    token.present?
  end

  # Counters live in Redis so the web process can report what the Sidekiq
  # process recorded. Tests keep them in memory.
  def store
    @store ||= Rails.env.test? ? MemoryStore.new : RedisStore.new
  end

  def store=(store)
    @store = store
  end

  def booted_at
    @booted_at ||= Time.current
  end
end
