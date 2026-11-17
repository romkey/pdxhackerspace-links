class OmniauthCallbacksController < ApplicationController
  skip_before_action :require_login

  def openid_connect
    auth = request.env["omniauth.auth"]
    user = User.from_omniauth(auth)
    session[:user_id] = user.id
    Metrics::Recorder.login(provider: "oidc", success: true)
    redirect_to root_path, notice: "Signed in."
  rescue ActiveRecord::RecordInvalid => e
    Metrics::Recorder.login(provider: "oidc", success: false)
    redirect_to login_path, alert: e.record.errors.full_messages.to_sentence
  end

  def failure
    Metrics::Recorder.login(provider: "oidc", success: false)
    redirect_to login_path, alert: params[:message].presence || "Authentication failed."
  end
end
