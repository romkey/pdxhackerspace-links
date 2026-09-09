module PrusaConnect
  # Exchanges and rotates OAuth refresh tokens against the Prusa account server.
  class AccessToken
    EXPIRY_SKEW = 60.seconds
    DEFAULT_CLIENT_ID = "MRHTlZhZqkNrrQ6FUPtjyusAz8nc59ErHXP8XkS4".freeze
    TOKEN_URL = "https://account.prusa3d.com/o/token/".freeze

    def self.ensure!(account, transport: nil)
      new(account: account, transport: transport).ensure!
    end

    def self.force_refresh!(account, transport: nil)
      new(account: account, transport: transport).force_refresh!
    end

    def initialize(account:, transport: nil)
      @account = account
      @transport = transport
    end

    def ensure!
      return account.access_token if account.access_token_valid?

      account.with_lock do
        account.reload
        return account.access_token if account.access_token_valid?

        refresh!
      end
    end

    def force_refresh!
      account.with_lock do
        account.reload
        refresh!
      end
    end

    private

    attr_reader :account

    def refresh!
      raise Client::AuthenticationError, "No refresh token is saved for this account." if account.refresh_token.blank?

      status, body = transport.call(
        URI(TOKEN_URL),
        "POST",
        { "Content-Type" => "application/x-www-form-urlencoded" },
        token_request_body
      )

      payload = parse_token_response(status, body)
      expires_at = token_expires_at(payload)

      account.update!(
        access_token: payload.fetch("access_token"),
        refresh_token: payload.fetch("refresh_token", account.refresh_token),
        access_token_expires_at: expires_at
      )

      account.access_token
    end

    def token_request_body
      {
        grant_type: "refresh_token",
        refresh_token: account.refresh_token,
        client_id: client_id
      }.to_query
    end

    def client_id
      ENV.fetch("PRUSA_CONNECT_CLIENT_ID", DEFAULT_CLIENT_ID)
    end

    def token_expires_at(payload)
      expires_in = payload["expires_in"].to_i
      return EXPIRY_SKEW.from_now if expires_in <= 0

      Time.current + expires_in.seconds
    end

    def parse_token_response(status, body)
      payload = JSON.parse(body.to_s)
      return payload if status == 200

      if payload["error"] == "invalid_grant"
        raise Client::AuthenticationError,
              "The refresh token is no longer valid. Sign in to Prusa Connect, copy a fresh " \
              "auth.refresh_token from browser local storage, and paste it here."
      end

      message = payload["error_description"].presence || payload["error"].presence || "HTTP #{status}"
      raise Client::AuthenticationError, "Prusa account rejected the token request: #{message}"
    rescue JSON::ParserError
      raise Client::Error, "Prusa account returned a response that is not JSON (HTTP #{status})"
    end

    def transport
      @transport ||= method(:perform_token_request)
    end

    def perform_token_request(uri, method, headers, body)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = Client::DEFAULT_TIMEOUT
      http.read_timeout = Client::DEFAULT_TIMEOUT

      request = Net::HTTP::Post.new(uri)
      headers.each { |name, value| request[name] = value }
      request.body = body

      response = http.request(request)
      [ response.code.to_i, response.body.to_s ]
    rescue Net::OpenTimeout, Net::ReadTimeout
      raise Client::ConnectionError, "Timed out connecting to #{uri.host}"
    rescue SocketError, SystemCallError, IOError => error
      raise Client::ConnectionError, "Cannot reach #{uri.host} (#{error.message})"
    end
  end
end
