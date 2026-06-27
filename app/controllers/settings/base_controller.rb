module Settings
  class BaseController < ApplicationController
    before_action :require_signed_in_user

    layout "application"
  end
end
