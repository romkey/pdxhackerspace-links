module ThingTracking
  QR_CODE = "qrcode"
  NFC = "nfc"
  SOURCES = [ QR_CODE, NFC ].freeze
  ABBREV_PARAMS = { "q" => QR_CODE, "n" => NFC }.freeze
  PARAM_ABBREVS = ABBREV_PARAMS.invert.freeze
  REDIRECT_SECONDS = 5

  module_function

  def tracked?(utm_source)
    SOURCES.include?(utm_source.to_s)
  end

  def short_param(utm_source)
    PARAM_ABBREVS.fetch(utm_source.to_s)
  end

  def utm_source_from_abbreviated(param)
    ABBREV_PARAMS[param.to_s]
  end

  def scan_utm_source_from(params)
    param_hash = params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : params.to_h
    stringified = param_hash.stringify_keys

    abbrev = ABBREV_PARAMS.keys.find { |key| stringified.key?(key) }
    return utm_source_from_abbreviated(abbrev) if abbrev

    source = stringified["utm_source"].to_s
    tracked?(source) ? source : nil
  end

  def thing_url(thing, utm_source:, **)
    ShortUrl.scan_url(thing, param: short_param(utm_source))
  end

  def full_thing_url(thing, utm_source:)
    Rails.application.routes.url_helpers.thing_url(
      thing,
      **AppHost.url_options,
      utm_source: utm_source
    )
  end
end
