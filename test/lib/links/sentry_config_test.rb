require "test_helper"

class Links::SentryConfigTest < ActiveSupport::TestCase
  test "enabled when sentry dsn is present" do
    with_env("SENTRY_DSN" => "https://examplePublicKey@o0.ingest.sentry.io/0") do
      assert Links::SentryConfig.enabled?
    end
  end

  test "disabled when sentry dsn is blank" do
    with_env("SENTRY_DSN" => nil) do
      assert_not Links::SentryConfig.enabled?
    end
  end

  test "environment_name defaults to rails env" do
    assert_equal "test", Links::SentryConfig.environment_name
  end

  test "environment_name respects sentry environment variable" do
    with_env("SENTRY_ENVIRONMENT" => "staging") do
      assert_equal "staging", Links::SentryConfig.environment_name
    end
  end

  test "release_name reads app version" do
    with_env("APP_VERSION" => "v1.2.3") do
      assert_equal "v1.2.3", Links::SentryConfig.release_name
    end
  end

  test "traces_sample_rate defaults to zero" do
    with_env("SENTRY_TRACES_SAMPLE_RATE" => nil) do
      assert_in_delta 0.0, Links::SentryConfig.traces_sample_rate
    end
  end

  test "traces_sample_rate parses env var" do
    with_env("SENTRY_TRACES_SAMPLE_RATE" => "0.25") do
      assert_in_delta 0.25, Links::SentryConfig.traces_sample_rate
    end
  end

  test "configure does not raise without dsn" do
    with_env("SENTRY_DSN" => nil) do
      assert_nil Links::SentryConfig.configure!
    end
  end

  private

  def with_env(overrides)
    previous = overrides.keys.index_with { |key| ENV[key] }
    overrides.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    yield
  ensure
    previous.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end
end
