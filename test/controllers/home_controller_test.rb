require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "requires authentication" do
    get root_path
    assert_redirected_to login_path
  end

  test "root shows things index for signed-in user" do
    sign_in_as(users(:local_admin))

    get root_path
    assert_response :success
    assert_select "h1", "Things"
  end
end
