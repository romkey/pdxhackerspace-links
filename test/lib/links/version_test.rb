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

  test "display adds v prefix to semver versions" do
    assert_equal "v1.2.3", Links::Version.display("1.2.3")
    assert_equal "v1.2.3", Links::Version.display("v1.2.3")
    assert_equal "staging", Links::Version.display("staging")
  end

  test "release_tag normalizes version tags" do
    assert_equal "v1.2.3", Links::Version.release_tag("1.2.3")
    assert_nil Links::Version.release_tag("staging")
  end
end
