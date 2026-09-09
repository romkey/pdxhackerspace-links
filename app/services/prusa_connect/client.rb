require "net/http"
require "openssl"

module PrusaConnect
  # Read-only HTTP client for the Prusa Connect cloud API.
  class Client
    class Error < StandardError; end
    class ConnectionError < Error; end
    class AuthenticationError < Error; end
    class NotFoundError < Error; end
    class RateLimitedError < Error; end

    DEFAULT_TIMEOUT = 10
    DEFAULT_PAGE_SIZE = 50
    MIN_REQUEST_INTERVAL = 0.25
    RATE_LIMIT_STATUS = 429
    MAX_ATTEMPTS = 3
    MAX_RETRY_AFTER = 30
    SNIPPET_LIMIT = 160
    CONNECT_HOST = "connect.prusa3d.com".freeze
    CONNECT_BASE_PATH = "/app".freeze

    attr_reader :account

    def self.for(account, transport: nil, access_token_service: nil, sleeper: nil, clock: nil)
      new(
        account: account,
        transport: transport,
        access_token_service: access_token_service,
        sleeper: sleeper,
        clock: clock
      )
    end

    def initialize(account:, transport: nil, access_token_service: nil, sleeper: nil, clock: nil)
      @account = account
      @transport = transport || method(:perform_request)
      @access_token_service = access_token_service || AccessToken
      @sleeper = sleeper || ->(seconds) { sleep(seconds) }
      @clock = clock || -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
      @last_request_at = nil
    end

    def printer_records
      list_printers.flat_map do |summary|
        uuid = summary["uuid"] || summary["id"]
        next [] if uuid.blank?

        detail = get("/printers/#{uuid}")
        [ PrinterRecord.from_payload(detail) ]
      end
    end

    def printer_count
      response = get("/printers", limit: 1, offset: 0)
      response.dig("pager", "total").to_i
    end

    def get(path, query = {})
      uri = uri_for(path, query)
      attempt = 0

      loop do
        attempt += 1
        pace_requests!
        status, body, response_headers = perform(uri)

        if status == RATE_LIMIT_STATUS && attempt < MAX_ATTEMPTS
          @sleeper.call(retry_after(response_headers, attempt))
          next
        end

        return parse(status, body, response_headers, path)
      end
    end

    private

    def list_printers
      printers = []
      offset = 0

      loop do
        response = get("/printers", limit: DEFAULT_PAGE_SIZE, offset: offset)
        page = Array(response["printers"])
        break if page.empty?

        printers.concat(page)
        total = response.dig("pager", "total").to_i
        offset += page.size
        break if total.positive? ? printers.size >= total : page.size < DEFAULT_PAGE_SIZE
      end

      printers
    end

    def pace_requests!
      return if @last_request_at.nil?

      elapsed = @clock.call - @last_request_at
      remaining = MIN_REQUEST_INTERVAL - elapsed
      @sleeper.call(remaining) if remaining.positive?
    ensure
      @last_request_at = @clock.call
    end

    def perform(uri)
      token = @access_token_service.ensure!(account)
      status, body, response_headers = @transport.call(uri, headers(token))
      [ status, body, response_headers || {} ]
    end

    def uri_for(path, query)
      normalized_path = path.start_with?("/") ? path : "/#{path}"
      URI::HTTPS.build(
        host: CONNECT_HOST,
        path: "#{CONNECT_BASE_PATH}#{normalized_path}",
        query: query.presence&.to_query
      )
    end

    def headers(token)
      {
        "Authorization" => "Bearer #{token}",
        "Accept" => "application/json"
      }
    end

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
        raise AuthenticationError, "Prusa Connect rejected the access token (HTTP #{status})"
      when 404
        raise NotFoundError, "Prusa Connect has no endpoint at #{CONNECT_BASE_PATH}#{path}"
      when RATE_LIMIT_STATUS
        raise RateLimitedError,
              "Prusa Connect is throttling requests (HTTP 429)#{error_detail(body)}"
      else
        raise Error, "Prusa Connect returned HTTP #{status}#{error_detail(body)}"
      end
    end

    def decode(body, status, response_headers)
      return {} if body.blank?

      JSON.parse(body)
    rescue JSON::ParserError
      raise Error,
            "Prusa Connect returned a response that is not JSON " \
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
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      http.open_timeout = DEFAULT_TIMEOUT
      http.read_timeout = DEFAULT_TIMEOUT

      request = Net::HTTP::Get.new(uri)
      request_headers.each { |name, value| request[name] = value }

      response = http.request(request)
      [ response.code.to_i, response.body.to_s, response.each_header.to_h ]
    rescue Net::OpenTimeout, Net::ReadTimeout
      raise ConnectionError, "Timed out connecting to #{uri.host}"
    rescue SocketError, SystemCallError, IOError => error
      raise ConnectionError, "Cannot reach #{uri.host} (#{error.message})"
    end
  end
end
