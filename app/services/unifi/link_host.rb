module Unifi
  # Links a UniFi Network host to the thing it belongs to. Hosts never create
  # things: a host links only to a thing that already has its MAC address or,
  # failing that, is the one thing with its IP address.
  #
  # Passing a thing links the host to it by hand, whatever its addresses, and
  # clears the host's ignored flag.
  #
  # The DHCP reservation and network name are the only values written back to
  # the thing, and each is kept in sync only until someone edits it by hand.
  class LinkHost
    SYNCED_ATTRIBUTES = %w[reserved_ip_address network_name].freeze

    def self.call(unifi_host:, thing: nil)
      new(unifi_host: unifi_host, thing: thing).call
    end

    def initialize(unifi_host:, thing: nil)
      @unifi_host = unifi_host
      @chosen_thing = thing
    end

    def call
      return :ignored if unifi_host.ignored? && chosen_thing.nil?

      # Read afresh: a cached thing would mistake a hand edit for the value this
      # host last wrote.
      thing = chosen_thing ? Thing.find(chosen_thing.id) : Thing.find_by(id: unifi_host.thing_id) || match
      return :unmatched if thing.nil?

      newly_linked = unifi_host.thing_id != thing.id
      # Values written to a previous thing say nothing about this one, even when
      # that link is already gone (ignoring a host or deleting its thing).
      unifi_host.applied_attributes = {} if newly_linked
      applied = apply_synced_attributes(thing)
      thing.save! if thing.changed?
      unifi_host.update!(thing: thing, applied_attributes: applied, ignored: false)

      newly_linked ? :linked : :updated
    end

    private

    attr_reader :unifi_host, :chosen_thing

    def match
      match_by_ieee_address || match_by_ip_address
    end

    def match_by_ieee_address
      Thing.find_by(ieee_address: unifi_host.ieee_address) if unifi_host.ieee_address.present?
    end

    # IP addresses are not unique on things, so an address shared by several
    # things matches none of them rather than guessing.
    def match_by_ip_address
      [ unifi_host.reserved_ip_address, unifi_host.ip_address ].compact_blank.uniq.each do |address|
        candidates = Thing.where(ip_address: address).limit(2).to_a
        return candidates.first if candidates.one?
      end
      nil
    end

    def apply_synced_attributes(thing)
      SYNCED_ATTRIBUTES.reduce(unifi_host.applied_attributes.presence || {}) do |applied, attribute|
        desired = unifi_host.public_send(attribute).presence
        current = thing.public_send(attribute)
        next applied unless current.blank? || current == applied[attribute]

        thing.public_send("#{attribute}=", desired)
        applied.merge(attribute => desired).compact
      end
    end
  end
end
