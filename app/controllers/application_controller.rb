class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  before_action :require_login
  before_action :set_sentry_user

  helper_method :current_user, :logged_in?, :oidc_login_available?, :local_login_available?

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def logged_in?
    current_user.present?
  end

  def require_login
    return if logged_in?

    redirect_to login_path, alert: "Please sign in to continue."
  end

  def oidc_login_available?
    ENV["OIDC_ISSUER"].present? &&
      ENV["OIDC_CLIENT_ID"].present? &&
      ENV["OIDC_CLIENT_SECRET"].present?
  end

  def local_login_available?
    User.local_auth_configured?
  end

  def set_sentry_user
    return unless Links::SentryConfig.enabled?

    if logged_in?
      Sentry.set_user(id: current_user.id.to_s, username: current_user.name)
    else
      Sentry.set_user({})
    end
  end
end
