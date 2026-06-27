module Things
  class RecordScan
    COUNTER_COLUMNS = {
      ThingTracking::QR_CODE => :qr_scan_count,
      ThingTracking::NFC => :nfc_scan_count
    }.freeze

    def self.call(thing:, utm_source:)
      new(thing: thing, utm_source: utm_source).call
    end

    def initialize(thing:, utm_source:)
      @thing = thing
      @utm_source = utm_source.to_s
    end

    def call
      column = COUNTER_COLUMNS[@utm_source]
      return unless column

      @thing.increment!(column)
    end
  end
end
