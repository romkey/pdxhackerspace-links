module Metrics
  # Builds the Prometheus text exposition format (version 0.0.4).
  #
  # Samples are either a bare number (no labels) or a hash of
  # { labels_hash => number }. Families with no samples are left out.
  class Exposition
    CONTENT_TYPE = "text/plain; version=0.0.4; charset=utf-8".freeze

    def initialize(prefix: Metrics::PREFIX)
      @prefix = prefix
      @lines = []
    end

    def gauge(name, help, samples)
      family(name, "gauge", help, samples)
    end

    def counter(name, help, samples)
      family(name, "counter", help, samples)
    end

    # buckets_by_labels holds the cumulative counts keyed by the series labels
    # plus "le"; sums and counts are keyed by the series labels alone. Every
    # bucket in +buckets+ is written, so a bucket nothing fell into reads 0.
    def histogram(name, help, buckets:, bucket_counts:, sums:, counts:)
      return if counts.empty?

      full = full_name(name)
      header(full, "histogram", help)
      counts.sort_by { |labels, _| labels.to_a }.each do |labels, count|
        labels = labels.transform_keys(&:to_s)
        buckets.each do |bucket|
          value = bucket_counts[labels.merge("le" => bucket.to_s).sort.to_h] || 0
          @lines << sample("#{full}_bucket", labels.merge("le" => bucket.to_s), value)
        end
        @lines << sample("#{full}_bucket", labels.merge("le" => "+Inf"), count)
        @lines << sample("#{full}_sum", labels, sums[labels] || 0)
        @lines << sample("#{full}_count", labels, count)
      end
    end

    def to_s
      @lines.join("\n") + "\n"
    end

    private

    def family(name, type, help, samples)
      samples = { {} => samples } unless samples.is_a?(Hash)
      samples = samples.reject { |_, value| value.nil? }
      return if samples.empty?

      full = full_name(name)
      header(full, type, help)
      samples.each { |labels, value| @lines << sample(full, labels, value) }
    end

    def full_name(name)
      "#{@prefix}_#{name}"
    end

    def header(full, type, help)
      @lines << "# HELP #{full} #{help.gsub("\\") { "\\\\" }.gsub("\n") { "\\n" }}"
      @lines << "# TYPE #{full} #{type}"
    end

    def sample(name, labels, value)
      rendered = labels.map { |key, label| %(#{key}="#{escape(label)}") }.join(",")
      rendered = "{#{rendered}}" unless rendered.empty?
      "#{name}#{rendered} #{number(value)}"
    end

    def escape(value)
      value.to_s.gsub("\\") { "\\\\" }.gsub('"') { '\\"' }.gsub("\n") { '\\n' }
    end

    def number(value)
      case value
      when true then "1"
      when false then "0"
      when Integer then value.to_s
      else
        float = value.to_f
        float.finite? && float == float.to_i ? float.to_i.to_s : float.to_s
      end
    end
  end
end
