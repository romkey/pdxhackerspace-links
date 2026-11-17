require "test_helper"

class Metrics::RecorderTest < ActiveJob::TestCase
  JOB = { "job" => "Unifi::ImportJob", "queue" => "default" }.freeze

  def read(metric)
    Metrics.store.read(metric)
  end

  test "counts a successful job run and its duration" do
    with_metrics_token do
      stubbing(Unifi::Import, :call, ->(**) { }) do
        Unifi::ImportJob.perform_now(unifi_controllers(:udm).id)
      end

      assert_equal({ JOB.merge("status" => "success") => 1.0 }, read("job_executions_total"))
      assert_equal 1.0, read("job_duration_seconds_count")[JOB]
      assert_operator read("job_duration_seconds_sum")[JOB], :>=, 0
      assert_equal 1.0, read("job_duration_seconds_bucket")[JOB.merge("le" => "600")]
      assert_in_delta Time.current.to_f, read("job_last_success_timestamp_seconds")[JOB], 5
      assert_in_delta Time.current.to_f, read("job_last_run_timestamp_seconds")[JOB], 5
      assert_empty read("job_failures_total")
      assert_empty read("job_last_failure_timestamp_seconds")
    end
  end

  test "counts a failed job run by error class" do
    with_metrics_token do
      stubbing(Unifi::Import, :call, ->(**) { raise Unifi::Client::ConnectionError, "Timed out" }) do
        assert_raises(Unifi::Client::ConnectionError) { Unifi::ImportJob.perform_now(unifi_controllers(:udm).id) }
      end

      assert_equal({ JOB.merge("status" => "failed") => 1.0 }, read("job_executions_total"))
      assert_equal({ JOB.merge("error" => "Unifi::Client::ConnectionError") => 1.0 }, read("job_failures_total"))
      assert_in_delta Time.current.to_f, read("job_last_failure_timestamp_seconds")[JOB], 5
      assert_empty read("job_last_success_timestamp_seconds")
    end
  end

  test "counts enqueued jobs and how long they waited" do
    with_metrics_token do
      stubbing(Unifi::Import, :call, ->(**) { }) do
        perform_enqueued_jobs { Unifi::ImportJob.perform_later(unifi_controllers(:udm).id) }
      end

      assert_equal({ JOB => 1.0 }, read("job_enqueued_total"))
      assert_equal 1.0, read("job_queue_wait_seconds_count")[JOB]
    end
  end

  test "does not record a queue wait for a job that was never queued" do
    with_metrics_token do
      stubbing(Unifi::Import, :call, ->(**) { }) do
        Unifi::ImportJob.perform_now(unifi_controllers(:udm).id)
      end

      assert_empty read("job_queue_wait_seconds_count")
    end
  end

  test "puts an observation in every bucket at or above it" do
    ops = Metrics::Recorder.observe("d", { job: "J" }, 3, [ 1, 3, 10 ])

    assert_equal [
      [ :incr, "d_bucket", { job: "J", le: 3 }, 1 ],
      [ :incr, "d_bucket", { job: "J", le: 10 }, 1 ],
      [ :incr, "d_sum", { job: "J" }, 3 ],
      [ :incr, "d_count", { job: "J" }, 1 ]
    ], ops
  end

  test "records nothing while metrics are off" do
    with_metrics_token(nil) do
      stubbing(Unifi::Import, :call, ->(**) { }) do
        Unifi::ImportJob.perform_now(unifi_controllers(:udm).id)
      end

      assert_empty read("job_executions_total")
    end
  end

  test "a failing store does not break the job" do
    with_metrics_token do
      broken = Object.new
      def broken.apply(_ops) = raise("redis is down")
      def broken.clear = nil
      original = Metrics.store
      Metrics.store = broken

      called = false
      stubbing(Unifi::Import, :call, ->(**) { called = true }) do
        assert_nothing_raised { Unifi::ImportJob.perform_now(unifi_controllers(:udm).id) }
      end
      assert called
    ensure
      Metrics.store = original
    end
  end
end
