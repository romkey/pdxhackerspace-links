module Unifi
  # Imports every device from a controller's enabled applications and populates
  # things from them. Safe to re-run: devices are keyed on their UniFi id, and
  # devices that disappear from the controller are archived rather than deleted.
  #
  # Network hosts (clients) are imported after the devices so their uplinks can
  # be named from the devices just read. Hosts only link to existing things.
  #
  # The two applications are imported independently so an outage or a permission
  # problem in one does not discard the inventory from the other.
  class Import
    Result = Data.define(
      :devices_created,
      :devices_updated,
      :devices_archived,
      :things_created,
      :things_linked,
      :hosts_seen,
      :hosts_linked,
      :hosts_archived,
      :notes,
      :errors
    ) do
      def success?
        errors.empty?
      end

      def devices_seen
        devices_created + devices_updated
      end

      def status
        return "success" if success?

        devices_seen.positive? || hosts_seen.positive? ? "partial" : "failed"
      end

      def summary
        counts = [
          "#{devices_seen} #{'device'.pluralize(devices_seen)}",
          ("#{devices_created} new" if devices_created.positive?),
          ("#{things_created} #{'thing'.pluralize(things_created)} created" if things_created.positive?),
          ("#{things_linked} linked" if things_linked.positive?),
          ("#{devices_archived} archived" if devices_archived.positive?),
          ("#{hosts_seen} #{'host'.pluralize(hosts_seen)}" if hosts_seen.positive?),
          ("#{hosts_linked} #{'host'.pluralize(hosts_linked)} linked" if hosts_linked.positive?),
          ("#{hosts_archived} #{'host'.pluralize(hosts_archived)} archived" if hosts_archived.positive?)
        ].compact.join(" · ")

        [ counts, notes.join("; ").presence, errors.join("; ").presence ].compact.join(" — ")
      end
    end

    def self.call(unifi_controller:, network_client: nil, protect_client: nil)
      new(unifi_controller: unifi_controller, network_client: network_client, protect_client: protect_client).call
    end

    def initialize(unifi_controller:, network_client: nil, protect_client: nil)
      @unifi_controller = unifi_controller
      @network_client = network_client
      @protect_client = protect_client
      @devices_created = 0
      @devices_updated = 0
      @devices_archived = 0
      @things_created = 0
      @things_linked = 0
      @hosts_seen = 0
      @hosts_linked = 0
      @hosts_archived = 0
      @notes = []
      @errors = []
      @failed_sources = []
    end

    def call
      import("network") { network_client.device_records } if unifi_controller.network_enabled?
      import("protect") { protect_client.device_records } if unifi_controller.protect_enabled?
      # Hosts come from the same application, so a Network outage would only
      # report the same error twice.
      import_hosts if unifi_controller.import_hosts? && @failed_sources.exclude?("network")

      build_result.tap { |result| record_sync(result) }
    end

    private

    attr_reader :unifi_controller

    def network_client
      @network_client ||= unifi_controller.network_client
    end

    def protect_client
      @protect_client ||= unifi_controller.protect_client
    end

    def import(source)
      seen = yield.filter_map { |record| upsert(record) }
      archive_missing(source, seen)
    rescue Client::Error => error
      @failed_sources << source
      @errors << "#{source.capitalize}: #{error.message}"
    end

    def upsert(record)
      device = unifi_controller.unifi_devices.find_or_initialize_by(
        source: record.source,
        external_id: record.external_id
      )
      created = device.new_record?
      now = Time.current

      device.assign_attributes(record.to_attributes.merge(last_seen_at: now, archived_at: nil))
      device.first_seen_at ||= now
      device.save!
      created ? @devices_created += 1 : @devices_updated += 1

      sync_thing(device)
      device.id
    rescue ActiveRecord::RecordInvalid => error
      @errors << "#{record.name.presence || record.external_id}: #{error.record.errors.full_messages.to_sentence}"
      device&.id
    end

    def sync_thing(device)
      case SyncThing.call(unifi_device: device, auto_create: unifi_controller.auto_create_things?)
      when :created then @things_created += 1
      when :linked then @things_linked += 1
      end
    end

    def archive_missing(source, seen_ids)
      scope = unifi_controller.unifi_devices.where(source: source).active
      scope = scope.where.not(id: seen_ids) if seen_ids.any?

      @devices_archived += scope.update_all(archived_at: Time.current, updated_at: Time.current)
    end

    def import_hosts
      inventory = network_client.host_inventory
      @notes.concat(inventory.notes.map { |note| "Hosts: #{note}" })
      seen = inventory.records.filter_map { |record| upsert_host(record) }
      retire_missing_hosts(seen, archive: inventory.complete?)
    rescue Client::Error => error
      @errors << "Hosts: #{error.message}"
    end

    def upsert_host(record)
      host = unifi_controller.unifi_hosts.find_or_initialize_by(
        site_external_id: record.site_external_id,
        ieee_address: record.ieee_address
      )
      host.assign_attributes(record.to_attributes.merge(imported_at: Time.current, archived_at: nil))
      host.uplink_name ||= uplink_device_name(record)
      host.save!
      @hosts_seen += 1

      @hosts_linked += 1 if LinkHost.call(unifi_host: host) == :linked
      host.id
    rescue ActiveRecord::RecordInvalid => error
      @errors << "#{record.name.presence || record.ieee_address}: #{error.record.errors.full_messages.to_sentence}"
      host&.id
    end

    def uplink_device_name(record)
      uplink_devices_by_mac[record.uplink_ieee_address] ||
        uplink_devices_by_id[record.payload.dig("integration", "uplinkDeviceId")]
    end

    def uplink_devices_by_mac
      @uplink_devices_by_mac ||= network_devices.each_with_object({}) do |device, index|
        index[device.ieee_address] = device.display_name if device.ieee_address.present?
      end
    end

    def uplink_devices_by_id
      @uplink_devices_by_id ||= network_devices.to_h { |device| [ device.external_id, device.display_name ] }
    end

    def network_devices
      @network_devices ||= unifi_controller.unifi_devices.source_network.to_a
    end

    # A host that has dropped off is offline either way. It is only archived
    # when the console's full client list was read, since the connected-only
    # fallback would otherwise archive everything that is switched off.
    def retire_missing_hosts(seen_ids, archive:)
      scope = unifi_controller.unifi_hosts.active
      scope = scope.where.not(id: seen_ids) if seen_ids.any?
      now = Time.current

      if archive
        @hosts_archived += scope.update_all(archived_at: now, online: false, updated_at: now)
      else
        scope.update_all(online: false, updated_at: now)
      end
    end

    def build_result
      Result.new(
        devices_created: @devices_created,
        devices_updated: @devices_updated,
        devices_archived: @devices_archived,
        things_created: @things_created,
        things_linked: @things_linked,
        hosts_seen: @hosts_seen,
        hosts_linked: @hosts_linked,
        hosts_archived: @hosts_archived,
        notes: @notes,
        errors: @errors
      )
    end

    def record_sync(result)
      unifi_controller.update!(
        last_synced_at: Time.current,
        last_sync_status: result.status,
        last_sync_message: result.summary
      )
    end
  end
end
