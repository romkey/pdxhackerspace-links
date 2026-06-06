require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "login page is reachable without authentication" do
    get login_path
    assert_response :success
    assert_select "h1", "Sign in"
  end

  test "logout clears session" do
    sign_in_as(users(:local_admin))

    delete logout_path
    assert_redirected_to login_path

    get root_path
    assert_redirected_to login_path
  end

  test "authenticated users visiting login are redirected home" do
    sign_in_as(users(:local_admin))

    get login_path
    assert_redirected_to root_path
  end
end
