module Unifi
  # Creates a thing from a UniFi Network host and links the host to it. Import
  # never does this on its own; it happens only when someone asks for it.
  class AddHostThing
    def self.call(unifi_host:)
      new(unifi_host: unifi_host).call
    end

    def initialize(unifi_host:)
      @unifi_host = unifi_host
    end

    # Returns the new thing, or an unsaved thing carrying its errors.
    def call
      thing = Thing.new(
        name: unifi_host.display_name,
        hostname: unifi_host.hostname,
        ieee_address: unifi_host.ieee_address,
        ip_address: unifi_host.ip_address,
        manufacturer: unifi_host.manufacturer
      )
      # UniFi reports whatever a client calls itself; drop a hostname or
      # address a thing would reject rather than refusing to add it.
      thing.valid?
      thing.hostname = nil if thing.errors.include?(:hostname)
      thing.ip_address = nil if thing.errors.include?(:ip_address)

      Thing.transaction do
        next unless thing.save

        LinkHost.call(unifi_host: unifi_host, thing: thing)
      end
      thing
    end

    private

    attr_reader :unifi_host
  end
end
