module PrusaConnect
  # Populates a thing from an imported Prusa Connect printer.
  class SyncThing
    def self.call(prusa_connect_printer:, auto_create: true)
      Integrations::SyncThing.call(integration_device: prusa_connect_printer, auto_create: auto_create)
    end
  end
end
