ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

class ActiveSupport::TestCase
  parallelize(workers: :number_of_processors)

  fixtures :all

  def sign_in_as(user)
    with_local_auth(email: user.email, password: "secret") do
      post local_login_path, params: { email: user.email, password: "secret" }
    end
  end

  def with_local_auth(email:, password: "secret")
    previous = %w[LOCAL_AUTH_EMAIL LOCAL_AUTH_PASSWORD LOCAL_AUTH_NAME].index_with { |key| ENV[key] }
    ENV["LOCAL_AUTH_EMAIL"] = email
    ENV["LOCAL_AUTH_PASSWORD"] = password
    ENV["LOCAL_AUTH_NAME"] = "Test User"
    yield
  ensure
    previous.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end
end
