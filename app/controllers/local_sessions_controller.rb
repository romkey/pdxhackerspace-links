class LocalSessionsController < ApplicationController
  skip_before_action :require_login

  def create
    unless User.local_auth_configured?
      redirect_to login_path, alert: "Local sign-in is not configured."
      return
    end

    user = User.authenticate_local(
      email: params[:email],
      password: params[:password]
    )

    if user
      session[:user_id] = user.id
      redirect_to root_path, notice: "Signed in."
    else
      flash.now[:alert] = "Invalid email or password."
      render "sessions/new", status: :unprocessable_entity
    end
  end
end
