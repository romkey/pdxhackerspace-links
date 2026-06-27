module Printers
  TestLabel = Data.define(:name, :owner, :ip_address, :subtitle) do
    LinkDisplay = Struct.new(:display_title, keyword_init: true)

    def label_title_line
      [ name, owner ].compact_blank.join(" ")
    end

    def label_ip_line
      ip_address
    end

    def links_with_urls
      [ LinkDisplay.new(display_title: subtitle) ]
    end

    def self.for_printer(printer)
      strip = printer.page_size == "label_strip_24mm" || printer.command?

      new(
        name: "Test label",
        owner: strip ? "Links" : nil,
        ip_address: strip ? "192.168.1.1" : nil,
        subtitle: printer.name
      )
    end
  end
end
