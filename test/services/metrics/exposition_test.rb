require "test_helper"

class Metrics::ExpositionTest < ActiveSupport::TestCase
  setup { @out = Metrics::Exposition.new }

  test "writes an unlabelled gauge with help and type" do
    @out.gauge("things_public", "Public things.", 3)

    assert_equal <<~TEXT, @out.to_s
      # HELP links_things_public Public things.
      # TYPE links_things_public gauge
      links_things_public 3
    TEXT
  end

  test "writes labelled samples and escapes label values" do
    @out.counter("logins_total", "Sign-ins.", { { provider: "a \"b\"\\c\nd" } => 2.0 })

    assert_includes @out.to_s, 'links_logins_total{provider="a \"b\"\\\\c\nd"} 2'.gsub("\n", '\n')
    assert_includes @out.to_s, "# TYPE links_logins_total counter"
  end

  test "renders booleans as 1 and 0 and keeps fractions" do
    @out.gauge("flags", "Flags.", { { on: "yes" } => true, { on: "no" } => false, { on: "half" } => 0.5 })

    assert_includes @out.to_s, 'links_flags{on="yes"} 1'
    assert_includes @out.to_s, 'links_flags{on="no"} 0'
    assert_includes @out.to_s, 'links_flags{on="half"} 0.5'
  end

  test "leaves out families with no samples and samples with no value" do
    @out.gauge("empty", "Nothing.", {})
    @out.gauge("missing", "Nothing.", nil)
    @out.gauge("partial", "Some.", { { a: "1" } => nil, { a: "2" } => 4 })

    assert_no_match(/links_empty|links_missing|a="1"/, @out.to_s)
    assert_includes @out.to_s, 'links_partial{a="2"} 4'
  end

  test "writes every histogram bucket, including ones nothing fell into" do
    labels = { "job" => "ImportJob" }
    @out.histogram("job_duration_seconds", "Run time.",
                   buckets: [ 0.1, 1, 5 ],
                   bucket_counts: { labels.merge("le" => "1") => 2.0, labels.merge("le" => "5") => 3.0 },
                   sums: { labels => 12.5 },
                   counts: { labels => 4.0 })

    assert_equal <<~TEXT, @out.to_s
      # HELP links_job_duration_seconds Run time.
      # TYPE links_job_duration_seconds histogram
      links_job_duration_seconds_bucket{job="ImportJob",le="0.1"} 0
      links_job_duration_seconds_bucket{job="ImportJob",le="1"} 2
      links_job_duration_seconds_bucket{job="ImportJob",le="5"} 3
      links_job_duration_seconds_bucket{job="ImportJob",le="+Inf"} 4
      links_job_duration_seconds_sum{job="ImportJob"} 12.5
      links_job_duration_seconds_count{job="ImportJob"} 4
    TEXT
  end
end
