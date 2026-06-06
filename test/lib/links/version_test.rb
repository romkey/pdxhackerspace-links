require "test_helper"

class Links::VersionTest < ActiveSupport::TestCase
  test "reads version from VERSION file" do
    previous = ENV.delete("APP_VERSION")
    assert_equal File.read(Rails.root.join("VERSION")).strip, Links::Version.current
  ensure
    ENV["APP_VERSION"] = previous if previous
  end

  test "prefers APP_VERSION environment variable" do
    previous = ENV["APP_VERSION"]
    ENV["APP_VERSION"] = "v9.9.9"
    assert_equal "v9.9.9", Links::Version.current
  ensure
    previous.nil? ? ENV.delete("APP_VERSION") : ENV["APP_VERSION"] = previous
  end
end
