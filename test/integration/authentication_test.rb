require "test_helper"

class AuthenticationTest < ActionDispatch::IntegrationTest
  test "footer displays application version" do
    sign_in_as(users(:local_admin))

    get root_path
    assert_select "footer", /v#{Regexp.escape(Links::Version.current)}/
  end

  test "health check does not require authentication" do
    get rails_health_check_path
    assert_response :success
  end
end
