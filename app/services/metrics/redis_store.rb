module Metrics
  # Counter store shared by every web and Sidekiq process. Each metric is one
  # Redis hash whose fields are the JSON-encoded label sets. Uses Sidekiq's
  # connection pool, so it follows REDIS_URL.
  class RedisStore
    DEFAULT_NAMESPACE = "links:metrics".freeze

    def initialize(namespace: DEFAULT_NAMESPACE)
      @namespace = namespace
    end

    # ops: [[:incr | :set, metric, labels, value], ...]
    def apply(ops)
      return if ops.empty?

      ::Sidekiq.redis do |conn|
        conn.pipelined do |pipe|
          ops.each do |op, metric, labels, value|
            command = op == :set ? "HSET" : "HINCRBYFLOAT"
            pipe.call(command, key(metric), field(labels), value.to_f.to_s)
          end
        end
      end
    end

    # => { { "label" => "value" } => Float }
    def read(metric)
      raw = ::Sidekiq.redis { |conn| conn.call("HGETALL", key(metric)) }
      raw = raw.each_slice(2).to_h if raw.is_a?(Array)
      raw.to_h { |encoded, value| [ JSON.parse(encoded), value.to_f ] }
    end

    def clear
      ::Sidekiq.redis do |conn|
        keys = conn.call("KEYS", "#{@namespace}:*")
        conn.call("DEL", *keys) if keys.any?
      end
    end

    private

    def key(metric)
      "#{@namespace}:#{metric}"
    end

    def field(labels)
      JSON.generate(labels.to_h { |name, value| [ name.to_s, value.to_s ] }.sort.to_h)
    end
  end
end
