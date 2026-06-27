require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "login page is reachable without authentication" do
    get login_path
    assert_response :success
    assert_select "h1", "Sign in"
  end

  test "login page shows local form when OIDC is not configured" do
    without_oidc_auth do
      get login_path
    end

    assert_response :success
    assert_select "details", count: 0
    assert_select "form[action=?]", local_login_path
    assert_select "input[type=email]"
    assert_select "input[type=password]"
  end

  test "login page hides local form in details when OIDC is configured" do
    with_oidc_auth do
      get login_path
    end

    assert_response :success
    assert_select "button", text: "Sign in with OpenID Connect"
    assert_select "details summary", text: "Sign in locally"
    assert_select "details form[action=?]", local_login_path
    assert_select "form[action=?]", local_login_path, count: 1
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

  private

  def with_oidc_auth
    previous = oidc_env_keys.index_with { |key| ENV[key] }
    ENV["OIDC_ISSUER"] = "https://auth.example.com/application/o/links/"
    ENV["OIDC_CLIENT_ID"] = "links-client"
    ENV["OIDC_CLIENT_SECRET"] = "links-secret"
    yield
  ensure
    previous.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end

  def without_oidc_auth
    previous = oidc_env_keys.index_with { |key| ENV[key] }
    oidc_env_keys.each { |key| ENV.delete(key) }
    yield
  ensure
    previous.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end

  def oidc_env_keys
    %w[OIDC_ISSUER OIDC_CLIENT_ID OIDC_CLIENT_SECRET OIDC_REDIRECT_URI]
  end
end
