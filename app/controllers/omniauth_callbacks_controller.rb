class OmniauthCallbacksController < ApplicationController
  skip_before_action :require_login

  def openid_connect
    auth = request.env["omniauth.auth"]
    user = User.from_omniauth(auth)
    session[:user_id] = user.id
    redirect_to root_path, notice: "Signed in."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to login_path, alert: e.record.errors.full_messages.to_sentence
  end

  def failure
    redirect_to login_path, alert: params[:message].presence || "Authentication failed."
  end
end
