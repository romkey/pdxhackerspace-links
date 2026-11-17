module Metrics
  module Collectors
    # Counters written by Metrics::Recorder as jobs, requests, and sign-ins happen.
    module Recorded
      COUNTERS = {
        "job_enqueued_total" => "Jobs enqueued, by job class and queue.",
        "job_executions_total" => "Job runs, by job class, queue, and whether they succeeded or failed.",
        "job_failures_total" => "Failed job runs, by job class, queue, and error class.",
        "http_requests_total" => "Requests handled, by controller, action, method, and response status.",
        "logins_total" => "Sign-in attempts, by provider and result."
      }.freeze

      GAUGES = {
        "job_last_run_timestamp_seconds" => "When the job last finished a run, successful or not.",
        "job_last_success_timestamp_seconds" => "When the job last succeeded.",
        "job_last_failure_timestamp_seconds" => "When the job last failed."
      }.freeze

      HISTOGRAMS = {
        "job_duration_seconds" => [ "Time jobs took to run.", Recorder::JOB_DURATION_BUCKETS ],
        "job_queue_wait_seconds" => [ "Time jobs waited in the queue before starting.", Recorder::JOB_WAIT_BUCKETS ],
        "http_request_duration_seconds" => [ "Time requests took, by controller and action.",
                                             Recorder::REQUEST_DURATION_BUCKETS ]
      }.freeze

      module_function

      def call(out)
        store = Metrics.store
        COUNTERS.each { |name, help| out.counter(name, help, store.read(name)) }
        GAUGES.each { |name, help| out.gauge(name, help, store.read(name)) }
        HISTOGRAMS.each do |name, (help, buckets)|
          out.histogram(name, help,
                        buckets: buckets,
                        bucket_counts: store.read("#{name}_bucket"),
                        sums: store.read("#{name}_sum"),
                        counts: store.read("#{name}_count"))
        end
      end
    end
  end
end
