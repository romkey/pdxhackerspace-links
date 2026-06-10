require "sidekiq/web"

Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }
end

class SidekiqWebAuth
  def initialize(app)
    @app = app
  end

  def call(env)
    request = ActionDispatch::Request.new(env)
    user_id = request.session[:user_id]

    if user_id && User.exists?(user_id)
      @app.call(env)
    else
      [ 302, { "Location" => "/login" }, [] ]
    end
  end
end

Sidekiq::Web.use SidekiqWebAuth
