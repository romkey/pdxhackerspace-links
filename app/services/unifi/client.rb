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

    DEFAULT_TIMEOUT = 10

    attr_reader :host, :port, :base_path

    def initialize(host:, api_key:, base_path:, port: 443, verify_tls: false, timeout: DEFAULT_TIMEOUT,
                   transport: nil)
      @host = host
      @api_key = api_key
      @base_path = base_path
      @port = port
      @verify_tls = verify_tls
      @timeout = timeout
      @transport = transport || method(:perform_request)
    end

    def get(path, query = {})
      status, body = @transport.call(uri_for(path, query), headers)
      parse(status, body, path)
    end

    private

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

    def parse(status, body, path)
      case status
      when 200..299
        decode(body)
      when 401, 403
        raise AuthenticationError, "UniFi rejected the API key (HTTP #{status})"
      when 404
        raise NotFoundError, "UniFi has no endpoint at #{base_path}#{path}"
      else
        raise Error, "UniFi returned HTTP #{status}#{error_detail(body)}"
      end
    end

    def decode(body)
      return {} if body.blank?

      JSON.parse(body)
    rescue JSON::ParserError
      raise Error, "UniFi returned a response that is not JSON"
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
      [ response.code.to_i, response.body.to_s ]
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
