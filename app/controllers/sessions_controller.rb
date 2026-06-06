class SessionsController < ApplicationController
  skip_before_action :require_login

  def new
    redirect_to root_path if logged_in?
  end

  def destroy
    reset_session
    redirect_to login_path, notice: "Signed out."
  end
end
