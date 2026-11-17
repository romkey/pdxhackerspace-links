require "test_helper"

class Metrics::StoresTest < ActiveSupport::TestCase
  def exercise(store)
    store.apply([
      [ :incr, "runs", { job: "A", queue: :default }, 1 ],
      [ :incr, "runs", { queue: "default", job: "A" }, 2.5 ],
      [ :incr, "runs", { job: "B", queue: "default" }, 1 ],
      [ :set, "last", { job: "A" }, 10 ],
      [ :set, "last", { job: "A" }, 20 ]
    ])

    assert_equal({
      { "job" => "A", "queue" => "default" } => 3.5,
      { "job" => "B", "queue" => "default" } => 1.0
    }, store.read("runs"))
    assert_equal({ { "job" => "A" } => 20.0 }, store.read("last"))
    assert_empty store.read("never_written")

    store.clear
    assert_empty store.read("runs")
  end

  test "memory store adds, sets, and ignores label order" do
    exercise(Metrics::MemoryStore.new)
  end

  test "redis store adds, sets, and ignores label order" do
    store = Metrics::RedisStore.new(namespace: "links:metrics:test:#{SecureRandom.hex(6)}")
    begin
      store.clear
    rescue RedisClient::CannotConnectError
      skip "Redis is not reachable"
    end

    exercise(store)
  ensure
    store&.clear rescue nil
  end
end
