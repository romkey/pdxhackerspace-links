class ApplicationController < ActionController::Base
  before_action :require_login
  before_action :set_sentry_user

  helper_method :current_user, :logged_in?, :network_guest?, :can_manage_things?,
                :oidc_login_available?, :local_login_available?

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def logged_in?
    current_user.present?
  end

  def network_guest?
    !logged_in? && network_whitelist_access?
  end

  def can_manage_things?
    logged_in?
  end

  def network_whitelist_access?
    Links::NetworkWhitelist.includes?(request.remote_ip)
  end

  def require_login
    return if logged_in?
    return if network_whitelist_access?

    redirect_to login_path, alert: "Please sign in to continue."
  end

  def require_signed_in_user
    return if logged_in?

    redirect_to login_path, alert: "Please sign in to continue."
  end

  def require_full_access
    return if logged_in?

    redirect_to root_path, alert: "Sign in to do that."
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
