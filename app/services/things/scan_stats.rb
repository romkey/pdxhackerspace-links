module Things
  ScanStats = Data.define(:qr_total, :nfc_total, :things, :sort, :direction) do
    SORTS = %w[name qr nfc total].freeze

    def self.call(sort: "total", direction: "desc")
      sort = SORTS.include?(sort.to_s) ? sort.to_s : "total"
      direction = direction.to_s.downcase == "asc" ? :asc : :desc

      things = case sort
      when "name"
                 Thing.order(name: direction)
      when "qr"
                 Thing.order(qr_scan_count: direction, name: :asc)
      when "nfc"
                 Thing.order(nfc_scan_count: direction, name: :asc)
      else
                 Thing.order(Arel.sql("(qr_scan_count + nfc_scan_count) #{direction.to_s.upcase}"), name: :asc)
      end

      new(
        qr_total: Thing.sum(:qr_scan_count),
        nfc_total: Thing.sum(:nfc_scan_count),
        things: things,
        sort: sort,
        direction: direction.to_s
      )
    end

    def total
      qr_total + nfc_total
    end
  end
end
