module ThingTracking
  QR_CODE = "qrcode"
  NFC = "nfc"
  SOURCES = [ QR_CODE, NFC ].freeze
  REDIRECT_SECONDS = 5

  module_function

  def tracked?(utm_source)
    SOURCES.include?(utm_source.to_s)
  end

  def thing_url(thing, utm_source:, **url_options)
    Rails.application.routes.url_helpers.thing_url(
      thing,
      **AppHost.url_options.merge(url_options),
      utm_source: utm_source
    )
  end
end
