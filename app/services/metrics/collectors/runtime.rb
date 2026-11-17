require "etc"

module Metrics
  module Collectors
    # The web process answering the scrape: Ruby, Puma, and the database pool.
    module Runtime
      PUMA_STATS = {
        running: [ "puma_threads", "Puma threads spawned." ],
        busy_threads: [ "puma_busy_threads", "Puma threads handling a request or waiting to." ],
        max_threads: [ "puma_max_threads", "Puma thread limit." ],
        pool_capacity: [ "puma_pool_capacity", "Requests Puma can take on right now." ],
        backlog: [ "puma_backlog", "Connections waiting for a Puma thread." ]
      }.freeze

      module_function

      def call(out)
        ruby(out)
        puma(out)
        database(out)
      end

      def ruby(out)
        out.gauge("web_threads", "Ruby threads in the web process.", Thread.list.size)
        out.counter("web_gc_runs_total", "Garbage collections in the web process.", GC.count)
        out.gauge("web_heap_live_slots", "Live Ruby heap slots in the web process.", GC.stat(:heap_live_slots))
        out.counter("web_allocated_objects_total", "Objects allocated by the web process.",
                    GC.stat(:total_allocated_objects))
        out.gauge("web_resident_memory_bytes", "Resident memory of the web process.", resident_memory)
      end

      def puma(out)
        stats = puma_stats
        return if stats.nil?

        PUMA_STATS.each do |key, (name, help)|
          out.gauge(name, help, stats[key]) if stats[key].is_a?(Numeric)
        end
        if stats[:requests_count].is_a?(Numeric)
          out.counter("puma_requests_total", "Requests Puma has handled.", stats[:requests_count])
        end
      end

      def database(out)
        stat = ActiveRecord::Base.connection_pool.stat
        out.gauge("db_pool_size", "Database connection pool limit.", stat[:size])
        out.gauge("db_pool_connections", "Database connections in the pool by state.",
                  %i[busy idle dead].to_h { |state| [ { state: state }, stat[state] ] })
        out.gauge("db_pool_waiting", "Threads waiting for a database connection.", stat[:waiting])
        out.gauge("database_size_bytes", "Size of the PostgreSQL database.",
                  ActiveRecord::Base.connection.select_value("SELECT pg_database_size(current_database())"))
      end

      # Only present in single mode (no Puma workers) and only while Puma is
      # the server; anything else reports no Puma metrics.
      def puma_stats
        return unless defined?(::Puma) && ::Puma.respond_to?(:stats_hash)

        stats = ::Puma.stats_hash
        stats if stats.is_a?(Hash)
      rescue StandardError
        nil
      end

      def resident_memory
        statm = "/proc/self/statm"
        return unless File.readable?(statm)

        File.read(statm).split[1].to_i * Etc.sysconf(Etc::SC_PAGESIZE)
      rescue StandardError
        nil
      end
    end
  end
end
