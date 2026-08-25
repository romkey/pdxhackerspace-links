require "test_helper"

class Links::RepositoryTest < ActiveSupport::TestCase
  test "defaults to the project repository url" do
    previous = ENV.delete("GITHUB_REPO_URL")
    assert_equal Links::Repository::DEFAULT_URL, Links::Repository.url
  ensure
    ENV["GITHUB_REPO_URL"] = previous if previous
  end

  test "prefers GITHUB_REPO_URL environment variable" do
    previous = ENV["GITHUB_REPO_URL"]
    ENV["GITHUB_REPO_URL"] = "https://github.com/example/fork"
    assert_equal "https://github.com/example/fork", Links::Repository.url
  ensure
    previous.nil? ? ENV.delete("GITHUB_REPO_URL") : ENV["GITHUB_REPO_URL"] = previous
  end

  test "release_url points at the tag release page" do
    assert_equal(
      "#{Links::Repository::DEFAULT_URL}/releases/tag/v1.2.3",
      Links::Repository.release_url("v1.2.3")
    )
  end

  test "release_url falls back to repository for non-tag versions" do
    assert_equal Links::Repository.url, Links::Repository.release_url("staging")
  end
end
