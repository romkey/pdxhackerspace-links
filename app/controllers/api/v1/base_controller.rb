module Api
  module V1
    # Read-only JSON API. Deliberately outside ApplicationController: requests
    # are authenticated by an API key sent as a bearer token, never by a
    # session or the network whitelist.
    class BaseController < ActionController::API
      include Pagy::Method

      before_action :authenticate_api_key!

      rescue_from ActiveRecord::RecordNotFound do
        render json: { error: "Not found" }, status: :not_found
      end

      private

      attr_reader :current_api_key

      def authenticate_api_key!
        token = request.authorization.to_s[/\ABearer\s+(\S+)\z/i, 1]
        @current_api_key = ApiKey.authenticate(token)
        return if current_api_key

        response.headers["WWW-Authenticate"] = 'Bearer realm="api"'
        render json: { error: "A valid API key is required" }, status: :unauthorized
      end
    end
  end
end
