require "uri"

module ShortUrl
  ENV_KEY = "SHORT_URL"
  LEGACY_ENV_KEY = "SHORT_URL_HOST"

  module_function

  def host
    ENV[ENV_KEY].presence || ENV[LEGACY_ENV_KEY].presence || ENV.fetch("APP_HOST", AppHost::DEFAULT)
  end

  def url_options
    AppHost.parse(host)
  end

  def thing_path(thing)
    "/#{thing.key}"
  end

  def display_url(thing)
    base = host.to_s.chomp("/")
    "#{base}#{thing_path(thing)}"
  end

  def scan_url(thing, param:)
    "#{display_url(thing)}?#{param}"
  end
end
