module Integrations
  # Turns automatic linking back on and links the device to its thing now.
  # Used after someone unlinked it, or to undo Ignore.
  class Relink
    def self.call(record:, auto_create:)
      new(record: record, auto_create: auto_create).call
    end

    def initialize(record:, auto_create:)
      @record = record
      @auto_create = auto_create
    end

    def call
      record.update!(auto_link: true, ignored: false)
      SyncThing.call(integration_device: record, auto_create: auto_create)
    end

    private

    attr_reader :record, :auto_create
  end
end
