module Integrations
  # Normalizes EUI-48 (12 hex) and EUI-64 (16 hex) hardware addresses into
  # lowercase colon-separated form for storage and matching.
  module HardwareAddress
    module_function

    def normalize(value)
      hex = value.to_s.downcase.delete_prefix("0x").gsub(/[^0-9a-f]/, "")
      return nil unless [ 12, 16 ].include?(hex.length)

      hex.scan(/../).join(":")
    end

    def display(value)
      normalized = normalize(value) || value.to_s
      return normalized if normalized.blank?

      octets = normalized.split(":")
      return "0x#{octets.join}" if octets.length == 8

      normalized
    end
  end
end
