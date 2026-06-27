require "uri"

module AppHost
  DEFAULT = "http://localhost:3000"

  def self.url_options(app_host = ENV.fetch("APP_HOST", DEFAULT))
    parse(app_host)
  end

  def self.parse(app_host)
    uri = URI.parse(app_host)
    options = { host: uri.host, protocol: uri.scheme }
    options[:port] = uri.port unless uri.port == uri.default_port
    options
  end
end
