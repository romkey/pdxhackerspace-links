require "test_helper"

class AuthenticationTest < ActionDispatch::IntegrationTest
  test "footer displays application version and github links" do
    sign_in_as(users(:local_admin))

    get root_path
    assert_select "footer a[href=?]", Links::Repository.url, text: "GitHub"
    assert_select "footer a[href=?]", Links::Repository.release_url(Links::Version.current),
                  text: Links::Version.display
  end

  test "health check does not require authentication" do
    get rails_health_check_path
    assert_response :success
  end
end
