require "net/http"
require "openssl"

module Unifi
  # Read-only HTTP client for the local UniFi integration APIs. Both the Network
  # and Protect applications are proxied by the console on port 443 and
  # authenticate with a stateless X-API-KEY header.
  class Client
    class Error < StandardError; end
    class ConnectionError < Error; end
    class AuthenticationError < Error; end
    class NotFoundError < Error; end
    class RateLimitedError < Error; end

    DEFAULT_TIMEOUT = 10
    RATE_LIMIT_STATUS = 429
    MAX_ATTEMPTS = 3
    MAX_RETRY_AFTER = 30
    SNIPPET_LIMIT = 160

    attr_reader :host, :port, :base_path

    def initialize(host:, api_key:, base_path:, port: 443, verify_tls: false, timeout: DEFAULT_TIMEOUT,
                   transport: nil, rate_limiter: nil, sleeper: nil, max_attempts: MAX_ATTEMPTS)
      @host = host
      @api_key = api_key
      @base_path = base_path
      @port = port
      @verify_tls = verify_tls
      @timeout = timeout
      @transport = transport || method(:perform_request)
      @rate_limiter = rate_limiter || RateLimiter.new
      @sleeper = sleeper || ->(seconds) { sleep(seconds) }
      @max_attempts = max_attempts
    end

    def get(path, query = {})
      uri = uri_for(path, query)
      attempt = 0

      loop do
        attempt += 1
        status, body, response_headers = perform(uri)

        if status == RATE_LIMIT_STATUS && attempt < @max_attempts
          @sleeper.call(retry_after(response_headers, attempt))
          next
        end

        return parse(status, body, response_headers, path)
      end
    end

    private

    def perform(uri)
      status, body, response_headers = @rate_limiter.throttle { @transport.call(uri, headers) }
      [ status, body, response_headers || {} ]
    end

    def uri_for(path, query)
      URI::HTTPS.build(
        host: host,
        port: port,
        path: "#{base_path}#{path}",
        query: query.presence&.to_query
      )
    end

    def headers
      { "X-API-KEY" => @api_key.to_s, "Accept" => "application/json" }
    end

    # UniFi sends Retry-After on a throttled response; back off exponentially
    # when it does not.
    def retry_after(response_headers, attempt)
      advertised = header(response_headers, "retry-after").to_f
      seconds = advertised.positive? ? advertised : 2**(attempt - 1)
      [ seconds, MAX_RETRY_AFTER ].min
    end

    def header(response_headers, name)
      return nil unless response_headers.respond_to?(:each_pair)

      _, value = response_headers.find { |key, _| key.to_s.downcase == name }
      value.is_a?(Array) ? value.first : value
    end

    def parse(status, body, response_headers, path)
      case status
      when 200..299
        decode(body, status, response_headers)
      when 401, 403
        raise AuthenticationError, "UniFi rejected the API key (HTTP #{status})"
      when 404
        raise NotFoundError, "UniFi has no endpoint at #{base_path}#{path}"
      when RATE_LIMIT_STATUS
        raise RateLimitedError,
              "UniFi is throttling requests (HTTP 429)#{error_detail(body)}. " \
              "A console allows about ten requests a second — wait a moment and run the import again."
      else
        raise Error, "UniFi returned HTTP #{status}#{error_detail(body)}"
      end
    end

    # A console answers with an HTML page rather than JSON when a request is
    # refused upstream of the API, so the status, type, and opening bytes are
    # reported to make that case identifiable.
    def decode(body, status, response_headers)
      return {} if body.blank?

      JSON.parse(body)
    rescue JSON::ParserError
      raise Error,
            "UniFi returned a response that is not JSON " \
            "(HTTP #{status}#{content_type_note(response_headers)}): #{snippet(body)}"
    end

    def content_type_note(response_headers)
      type = header(response_headers, "content-type").to_s.split(";").first
      type.present? ? ", #{type}" : ""
    end

    def snippet(body)
      body.to_s.gsub(/\s+/, " ").strip.truncate(SNIPPET_LIMIT)
    end

    def error_detail(body)
      payload = JSON.parse(body.to_s)
      message = payload["message"] || payload["error"] || payload["code"] if payload.is_a?(Hash)
      message.present? ? ": #{message}" : ""
    rescue JSON::ParserError
      ""
    end

    def perform_request(uri, request_headers)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = @verify_tls ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE
      http.open_timeout = @timeout
      http.read_timeout = @timeout

      request = Net::HTTP::Get.new(uri)
      request_headers.each { |name, value| request[name] = value }

      response = http.request(request)
      [ response.code.to_i, response.body.to_s, response.each_header.to_h ]
    rescue OpenSSL::SSL::SSLError => error
      raise ConnectionError,
            "TLS error connecting to #{uri.host}: #{error.message}. " \
            "UniFi consoles ship a self-signed certificate — turn off certificate verification or install a trusted one."
    rescue Net::OpenTimeout, Net::ReadTimeout
      raise ConnectionError, "Timed out connecting to #{uri.host}:#{uri.port}"
    rescue SocketError, SystemCallError, IOError => error
      raise ConnectionError, "Cannot reach #{uri.host}:#{uri.port} (#{error.message})"
    end
  end
end
