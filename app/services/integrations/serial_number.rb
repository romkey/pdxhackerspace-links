module Integrations
  # Pulls a hardware serial out of a raw integration payload.
  #
  # Neither the UniFi nor the Zigbee2MQTT device schema promises a serial, and
  # the vendors that do expose one disagree on what to call it, so this reads
  # the whole stored payload rather than a fixed field. Only top-level keys are
  # considered: nested objects such as a Protect camera's storage drives carry
  # their own unrelated serials.
  class SerialNumber
    KEYS = %w[serialNumber serial_number serialNo serial_no serial].freeze

    # Loose on purpose — serials vary wildly between vendors. This only rules
    # out values that clearly are not one, such as placeholders or blobs.
    FORMAT = /\A[A-Za-z0-9][A-Za-z0-9 ._:\/-]{2,63}\z/
    PLACEHOLDERS = %w[unknown unavailable none n/a null 0].freeze

    def self.extract(payload)
      return nil unless payload.respond_to?(:[])

      KEYS.each do |key|
        value = normalize(payload[key])
        return value if value
      end

      nil
    end

    def self.normalize(value)
      return nil unless value.is_a?(String) || value.is_a?(Integer)

      candidate = value.to_s.strip
      return nil if candidate.blank?
      return nil if PLACEHOLDERS.include?(candidate.downcase)
      return nil unless candidate.match?(FORMAT)

      candidate
    end
    private_class_method :normalize
  end
end
