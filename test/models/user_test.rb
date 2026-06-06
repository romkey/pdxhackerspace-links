require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "normalizes email to lowercase" do
    user = User.new(email: "  Test@Example.COM ", name: "Test", password: "secret")
    user.valid?
    assert_equal "test@example.com", user.email
  end

  test "local account requires password" do
    user = User.new(email: "local@example.com", name: "Local")
    assert_not user.valid?
    assert_includes user.errors[:password], "can't be blank"
  end

  test "oidc account requires uid when provider is set" do
    user = User.new(email: "oidc@example.com", name: "OIDC", provider: "openid_connect")
    assert_not user.valid?
    assert_includes user.errors[:uid], "can't be blank"
  end

  test "authenticate_local returns user with matching credentials" do
    with_local_auth(email: "local@example.com", password: "secret") do
      user = users(:local_admin)
      user.update!(password: "secret", provider: nil, uid: nil)

      assert_equal user, User.authenticate_local(email: "local@example.com", password: "secret")
      assert_nil User.authenticate_local(email: "local@example.com", password: "wrong")
    end
  end

  test "ensure_local_account creates account from environment" do
    with_local_auth(email: "admin@example.com", password: "local-pass", name: "Admin") do
      assert_difference -> { User.count }, 1 do
        User.ensure_local_account!
      end

      user = User.find_by!(email: "admin@example.com")
      assert user.authenticate("local-pass")
      assert user.local_account?
    end
  end

  private

  def with_local_auth(email:, password:, name: "Local")
    previous = %w[LOCAL_AUTH_EMAIL LOCAL_AUTH_PASSWORD LOCAL_AUTH_NAME].index_with { |key| ENV[key] }
    ENV["LOCAL_AUTH_EMAIL"] = email
    ENV["LOCAL_AUTH_PASSWORD"] = password
    ENV["LOCAL_AUTH_NAME"] = name
    yield
  ensure
    previous.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end
end
