module Unifi
  # UniFi OS throttles the integration APIs to ten requests a second per console
  # and the ceiling cannot be raised, so bursts have to be paced here. An import
  # walks a dozen Protect endpoints back to back and would otherwise be refused
  # part way through.
  #
  # Both applications on a console draw from the same budget, so one limiter is
  # shared between a controller's Network and Protect clients.
  class RateLimiter
    DEFAULT_MAX_REQUESTS = 8
    DEFAULT_PERIOD = 1.0

    def initialize(max_requests: DEFAULT_MAX_REQUESTS, period: DEFAULT_PERIOD, clock: nil, sleeper: nil)
      @max_requests = max_requests
      @period = period
      @clock = clock || -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
      @sleeper = sleeper || ->(seconds) { sleep(seconds) }
      @timestamps = []
      @mutex = Mutex.new
    end

    # Reserves a slot before yielding. The reservation is held under the mutex
    # but the request itself is not, so a slow response cannot block other
    # threads from queueing behind it.
    def throttle
      @mutex.synchronize { reserve_slot }
      yield
    end

    private

    def reserve_slot
      prune

      if @timestamps.size >= @max_requests
        delay = @period - (@clock.call - @timestamps.first)
        @sleeper.call(delay) if delay.positive?
        prune
      end

      @timestamps << @clock.call
    end

    def prune
      cutoff = @clock.call - @period
      @timestamps.reject! { |timestamp| timestamp <= cutoff }
    end
  end
end
