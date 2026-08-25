module Zigbee2mqtt
  module ManufacturerUrl
    BASE = "https://www.zigbee2mqtt.io/devices".freeze

    module_function

    def for(model)
      slug = model.to_s.strip
      return nil if slug.blank?

      "#{BASE}/#{ERB::Util.url_encode(slug)}.html"
    end
  end
end
