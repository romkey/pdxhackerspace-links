require "test_helper"

class Unifi::RateLimiterTest < ActiveSupport::TestCase
  # A fake clock that only moves when the limiter sleeps, so pacing decisions
  # are deterministic rather than dependent on how fast the suite runs.
  def build_limiter(max_requests: 3, period: 1.0)
    @now = 0.0
    @slept = []

    Unifi::RateLimiter.new(
      max_requests: max_requests,
      period: period,
      clock: -> { @now },
      sleeper: ->(seconds) { @slept << seconds; @now += seconds }
    )
  end

  test "returns the value of the block" do
    assert_equal :result, build_limiter.throttle { :result }
  end

  test "does not delay while under the limit" do
    limiter = build_limiter(max_requests: 3)

    3.times { limiter.throttle { :ok } }

    assert_empty @slept
  end

  test "waits for the window to roll over once the limit is reached" do
    limiter = build_limiter(max_requests: 3, period: 1.0)

    4.times { limiter.throttle { :ok } }

    assert_equal [ 1.0 ], @slept
  end

  test "paces a long burst to the configured rate" do
    limiter = build_limiter(max_requests: 3, period: 1.0)

    9.times { limiter.throttle { :ok } }

    assert_equal [ 1.0, 1.0 ], @slept
    assert_equal 2.0, @now
  end
end
