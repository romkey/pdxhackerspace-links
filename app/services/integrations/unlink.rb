module Integrations
  # Detaches an imported device or host from its thing. Later imports leave it
  # unlinked instead of matching it again or creating a replacement thing.
  # Linking by hand turns automatic linking back on. The thing keeps the values
  # it already has.
  class Unlink
    def self.call(record)
      new(record).call
    end

    def initialize(record)
      @record = record
    end

    def call
      thing = record.thing
      return record if thing.nil?

      record.update!(thing: nil, auto_link: false)
      # Touch so the thing's last-changed time moves with the detachment.
      # The journal is suspended inside the block, so this stays one entry.
      thing.journaled("unlinked", message: journal_message) { thing.touch }
      record
    end

    private

    attr_reader :record

    def journal_message
      "#{source_label} · #{record.display_name}"
    end

    def source_label
      return "UniFi host" if record.is_a?(UnifiHost)

      Registry.label_for(record.integration_source)
    end
  end
end
