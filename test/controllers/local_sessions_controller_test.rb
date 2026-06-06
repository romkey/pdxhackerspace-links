require "test_helper"

class LocalSessionsControllerTest < ActionDispatch::IntegrationTest
  test "creates session for configured local account" do
    with_local_auth(email: "local@example.com", password: "secret") do
      user = users(:local_admin)
      user.update!(password: "secret", provider: nil, uid: nil)

      post local_login_path, params: { email: "local@example.com", password: "secret" }
      assert_redirected_to root_path

      get root_path
      assert_response :success
    end
  end

  test "rejects invalid credentials" do
    with_local_auth(email: "local@example.com", password: "secret") do
      users(:local_admin).update!(password: "secret", provider: nil, uid: nil)

      post local_login_path, params: { email: "local@example.com", password: "wrong" }
      assert_response :unprocessable_entity
      assert_select ".alert", /Invalid email or password/
    end
  end

  test "rejects local login when not configured" do
    previous = %w[LOCAL_AUTH_EMAIL LOCAL_AUTH_PASSWORD].index_with { |key| ENV[key] }
    ENV.delete("LOCAL_AUTH_EMAIL")
    ENV.delete("LOCAL_AUTH_PASSWORD")

    post local_login_path, params: { email: "local@example.com", password: "secret" }
    assert_redirected_to login_path
    assert_equal "Local sign-in is not configured.", flash[:alert]
  ensure
    previous.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end

  private

  def with_local_auth(email:, password:)
    previous = %w[LOCAL_AUTH_EMAIL LOCAL_AUTH_PASSWORD].index_with { |key| ENV[key] }
    ENV["LOCAL_AUTH_EMAIL"] = email
    ENV["LOCAL_AUTH_PASSWORD"] = password
    yield
  ensure
    previous.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end
end
