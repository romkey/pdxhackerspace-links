oidc_configured = ENV["OIDC_ISSUER"].present? &&
                  ENV["OIDC_CLIENT_ID"].present? &&
                  ENV["OIDC_CLIENT_SECRET"].present?

oidc_redirect_uri = ENV.fetch("OIDC_REDIRECT_URI") do
  host = ENV.fetch("APP_HOST", "http://localhost:3000")
  "#{host.chomp('/')}/auth/openid_connect/callback"
end

Rails.application.config.middleware.use OmniAuth::Builder do
  if oidc_configured
    provider :openid_connect,
             name: :openid_connect,
             scope: %i[openid email profile],
             response_type: :code,
             issuer: ENV.fetch("OIDC_ISSUER"),
             discovery: true,
             client_options: {
               identifier: ENV.fetch("OIDC_CLIENT_ID"),
               secret: ENV.fetch("OIDC_CLIENT_SECRET"),
               redirect_uri: oidc_redirect_uri
             }
  end
end

OmniAuth.config.allowed_request_methods = %i[post get]
OmniAuth.config.silence_get_warning = true
