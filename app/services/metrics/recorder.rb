module Metrics
  # Records events as they happen (jobs, requests, sign-ins) into the shared
  # store. Recording must never break the work being measured, so store
  # failures are logged and swallowed.
  module Recorder
    JOB_DURATION_BUCKETS = [ 0.1, 0.5, 1, 2.5, 5, 10, 30, 60, 120, 300, 600 ].freeze
    JOB_WAIT_BUCKETS = [ 0.1, 0.5, 1, 5, 15, 60, 300, 900, 3600 ].freeze
    REQUEST_DURATION_BUCKETS = [ 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10 ].freeze

    module_function

    def job_enqueued(job)
      write([ [ :incr, "job_enqueued_total", job_labels(job), 1 ] ])
    end

    def job_performed(job, duration:, error: nil, now: Time.current)
      labels = job_labels(job)
      status = error ? "failed" : "success"
      ops = [
        [ :incr, "job_executions_total", labels.merge(status: status), 1 ],
        [ :set, "job_last_run_timestamp_seconds", labels, now.to_f ],
        [ :set, "job_last_#{error ? 'failure' : 'success'}_timestamp_seconds", labels, now.to_f ]
      ]
      ops << [ :incr, "job_failures_total", labels.merge(error: error.class.name), 1 ] if error
      ops.concat(observe("job_duration_seconds", labels, duration, JOB_DURATION_BUCKETS))

      wait = queue_wait(job, started_at: now - duration)
      ops.concat(observe("job_queue_wait_seconds", labels, wait, JOB_WAIT_BUCKETS)) if wait
      write(ops)
    end

    def request(controller:, action:, method:, status:, duration:)
      labels = { controller: controller.to_s, action: action.to_s }
      ops = [ [ :incr, "http_requests_total", labels.merge(method: method.to_s.upcase, status: status.to_s), 1 ] ]
      ops.concat(observe("http_request_duration_seconds", labels, duration, REQUEST_DURATION_BUCKETS))
      write(ops)
    end

    def login(provider:, success:)
      write([ [ :incr, "logins_total", { provider: provider, result: success ? "success" : "failure" }, 1 ] ])
    end

    # Buckets are stored cumulatively, the way Prometheus exposes them.
    def observe(name, labels, value, buckets)
      ops = buckets.select { |bucket| value <= bucket }.map do |bucket|
        [ :incr, "#{name}_bucket", labels.merge(le: bucket), 1 ]
      end
      ops << [ :incr, "#{name}_sum", labels, value ]
      ops << [ :incr, "#{name}_count", labels, 1 ]
    end

    def job_labels(job)
      { job: job.class.name, queue: job.queue_name.to_s }
    end

    def queue_wait(job, started_at:)
      enqueued_at = job.enqueued_at
      return if enqueued_at.blank?

      enqueued_at = Time.iso8601(enqueued_at) if enqueued_at.is_a?(String)
      [ started_at - enqueued_at, 0.0 ].max
    rescue ArgumentError
      nil
    end

    def write(ops)
      return unless Metrics.enabled?

      Metrics.store.apply(ops)
    rescue StandardError => error
      Rails.logger.warn("Metrics recording failed: #{error.class}: #{error.message}")
    end
  end
end
