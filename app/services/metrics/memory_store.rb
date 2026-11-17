module Metrics
  # In-process counter store, used by the test environment.
  class MemoryStore
    def initialize
      @data = Hash.new { |hash, metric| hash[metric] = Hash.new(0.0) }
      @mutex = Mutex.new
    end

    # ops: [[:incr | :set, metric, labels, value], ...]
    def apply(ops)
      @mutex.synchronize do
        ops.each do |op, metric, labels, value|
          key = normalize(labels)
          op == :set ? @data[metric][key] = value.to_f : @data[metric][key] += value.to_f
        end
      end
    end

    # => { { "label" => "value" } => Float }
    def read(metric)
      @mutex.synchronize { @data.key?(metric) ? @data[metric].dup : {} }
    end

    def clear
      @mutex.synchronize { @data.clear }
    end

    private

    def normalize(labels)
      labels.to_h { |key, value| [ key.to_s, value.to_s ] }.sort.to_h
    end
  end
end
