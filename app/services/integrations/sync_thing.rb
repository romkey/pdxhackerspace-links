module Integrations
  # Links an imported integration device to a thing, matching by IEEE address.
  class SyncThing
    MANAGED_ATTRIBUTES = %w[
      name ip_address ieee_address manufacturer model manufacturer_url integration_source
    ].freeze

    def self.call(integration_device:, auto_create: true)
      new(integration_device: integration_device, auto_create: auto_create).call
    end

    def initialize(integration_device:, auto_create: true)
      @integration_device = integration_device
      @auto_create = auto_create
    end

    def call
      return :ignored if integration_device.ignored?

      thing = integration_device.thing || match_by_ieee_address
      return update_thing(thing) if thing
      return :skipped unless auto_create?

      create_thing
    end

    private

    attr_reader :integration_device

    def auto_create?
      @auto_create
    end

    def match_by_ieee_address
      address = integration_device.ieee_address
      return nil if address.blank?

      Thing.find_by(ieee_address: address)
    end

    def create_thing
      thing = Thing.new
      applied = apply_attributes(thing)
      thing.name = integration_device.fallback_thing_name if thing.name.blank?
      thing.save!

      integration_device.update!(thing: thing, applied_attributes: applied.merge("name" => thing.name))
      :created
    end

    def update_thing(thing)
      newly_linked = integration_device.thing_id != thing.id
      applied = apply_attributes(thing)
      thing.save!

      integration_device.update!(thing: thing, applied_attributes: applied)
      newly_linked ? :linked : :updated
    end

    def apply_attributes(thing)
      applied = integration_device.applied_attributes.presence || {}

      desired_attributes.each do |attribute, value|
        current = thing.public_send(attribute)
        next unless current.blank? || current == applied[attribute]

        thing.public_send("#{attribute}=", value)
        applied = applied.merge(attribute => value)
      end

      applied
    end

    def desired_attributes
      integration_device.desired_thing_attributes.merge(
        "integration_source" => integration_device.integration_source
      ).compact
    end
  end
end
