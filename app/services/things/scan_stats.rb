module Things
  ScanStats = Data.define(:qr_total, :nfc_total, :by_total, :by_qr, :by_nfc) do
    def self.call
      qr_total = Thing.sum(:qr_scan_count)
      nfc_total = Thing.sum(:nfc_scan_count)

      new(
        qr_total: qr_total,
        nfc_total: nfc_total,
        by_total: Thing.order(Arel.sql("(qr_scan_count + nfc_scan_count) DESC"), :name),
        by_qr: Thing.order(qr_scan_count: :desc, name: :asc),
        by_nfc: Thing.order(nfc_scan_count: :desc, name: :asc)
      )
    end

    def total
      qr_total + nfc_total
    end
  end
end
