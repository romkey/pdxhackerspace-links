module Unifi
  # Populates a thing from an imported UniFi device.
  #
  # Devices are matched to existing things by MAC address, so a console that
  # appears in both the Network and Protect APIs maps to a single thing. Fields
  # edited by hand are never overwritten: the values written by the last import
  # are remembered on the device, and a field is only refreshed while the thing
  # still holds that value.
  class SyncThing
    MANAGED_ATTRIBUTES = %w[name ip_address mac_address].freeze

    def self.call(unifi_device:, auto_create: true)
      new(unifi_device: unifi_device, auto_create: auto_create).call
    end

    def initialize(unifi_device:, auto_create: true)
      @unifi_device = unifi_device
      @auto_create = auto_create
    end

    def call
      return :ignored if unifi_device.ignored?

      thing = unifi_device.thing || match_by_mac_address
      return update_thing(thing) if thing
      return :skipped unless auto_create?

      create_thing
    end

    private

    attr_reader :unifi_device

    def auto_create?
      @auto_create
    end

    def match_by_mac_address
      return nil if unifi_device.mac_address.blank?

      Thing.find_by(mac_address: unifi_device.mac_address)
    end

    def create_thing
      thing = Thing.new
      applied = apply_attributes(thing)
      thing.name = fallback_name if thing.name.blank?
      thing.save!

      unifi_device.update!(thing: thing, applied_attributes: applied.merge("name" => thing.name))
      :created
    end

    def update_thing(thing)
      newly_linked = unifi_device.thing_id != thing.id
      applied = apply_attributes(thing)
      thing.save!

      unifi_device.update!(thing: thing, applied_attributes: applied)
      newly_linked ? :linked : :updated
    end

    def apply_attributes(thing)
      applied = unifi_device.applied_attributes.presence || {}

      desired_attributes.each do |attribute, value|
        current = thing.public_send(attribute)
        next unless current.blank? || current == applied[attribute]

        thing.public_send("#{attribute}=", value)
        applied = applied.merge(attribute => value)
      end

      applied
    end

    def desired_attributes
      {
        "name" => unifi_device.name.presence,
        "ip_address" => unifi_device.ip_address.presence,
        "mac_address" => unifi_device.mac_address.presence
      }.compact
    end

    def fallback_name
      identifier = unifi_device.mac_address.presence || unifi_device.external_id
      "#{unifi_device.kind_label} #{identifier}"
    end
  end
end
