require "sidekiq/api"

module Metrics
  module Collectors
    # Sidekiq's own view: queues, backlog, the worker servers, and Redis.
    module Sidekiq
      module_function

      def call(out)
        totals(out)
        queues(out)
        processes(out)
        redis(out)
      end

      def totals(out)
        stats = ::Sidekiq::Stats.new
        out.counter("sidekiq_processed_total", "Jobs Sidekiq has processed.", stats.processed)
        out.counter("sidekiq_failed_total", "Job runs Sidekiq has seen fail.", stats.failed)
        out.gauge("sidekiq_enqueued", "Jobs waiting in all queues.", stats.enqueued)
        out.gauge("sidekiq_scheduled", "Jobs scheduled to run later.", stats.scheduled_size)
        out.gauge("sidekiq_retries", "Failed jobs waiting to be retried.", stats.retry_size)
        out.gauge("sidekiq_dead", "Jobs that ran out of retries.", stats.dead_size)
        out.gauge("sidekiq_busy", "Jobs running right now.", stats.workers_size)
      end

      def queues(out)
        all = ::Sidekiq::Queue.all
        out.gauge("sidekiq_queue_size", "Jobs waiting in the queue.",
                  all.to_h { |queue| [ { queue: queue.name }, queue.size ] })
        out.gauge("sidekiq_queue_latency_seconds", "Age of the oldest job waiting in the queue.",
                  all.to_h { |queue| [ { queue: queue.name }, queue.latency ] })
      end

      def processes(out)
        by_host = ::Sidekiq::ProcessSet.new.group_by { |process| process["hostname"].to_s }
        per_host = ->(&value) { by_host.to_h { |host, list| [ { hostname: host }, value.call(list) ] } }

        out.gauge("sidekiq_processes", "Sidekiq processes alive, by server.", per_host.call(&:size))
        out.gauge("sidekiq_process_concurrency", "Job threads available, by server.",
                  per_host.call { |list| list.sum { |process| process["concurrency"].to_i } })
        out.gauge("sidekiq_process_busy", "Job threads in use, by server.",
                  per_host.call { |list| list.sum { |process| process["busy"].to_i } })
        out.gauge("sidekiq_process_resident_memory_bytes", "Resident memory of Sidekiq processes, by server.",
                  per_host.call { |list| list.sum { |process| process["rss"].to_i } * 1024 })
        out.gauge("sidekiq_process_start_time_seconds", "When the oldest Sidekiq process on the server started.",
                  per_host.call { |list| list.filter_map { |process| process["started_at"]&.to_f }.min })
      end

      def redis(out)
        info = ::Sidekiq.default_configuration.redis_info
        out.gauge("redis_used_memory_bytes", "Memory Redis is using.", info["used_memory"]&.to_i)
        out.gauge("redis_connected_clients", "Clients connected to Redis.", info["connected_clients"]&.to_i)
        out.gauge("redis_uptime_seconds", "How long Redis has been up.", info["uptime_in_seconds"]&.to_i)
      end
    end
  end
end
