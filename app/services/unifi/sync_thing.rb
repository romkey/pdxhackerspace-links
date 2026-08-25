module Unifi
  # Populates a thing from an imported UniFi device.
  class SyncThing
    def self.call(unifi_device:, auto_create: true)
      Integrations::SyncThing.call(integration_device: unifi_device, auto_create: auto_create)
    end
  end
end
