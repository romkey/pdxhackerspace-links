module Unifi
  # Imports every device from a controller's enabled applications and populates
  # things from them. Safe to re-run: devices are keyed on their UniFi id, and
  # devices that disappear from the controller are archived rather than deleted.
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

        devices_seen.positive? ? "partial" : "failed"
      end

      def summary
        counts = [
          "#{devices_seen} #{'device'.pluralize(devices_seen)}",
          ("#{devices_created} new" if devices_created.positive?),
          ("#{things_created} #{'thing'.pluralize(things_created)} created" if things_created.positive?),
          ("#{things_linked} linked" if things_linked.positive?),
          ("#{devices_archived} archived" if devices_archived.positive?)
        ].compact.join(" · ")

        [ counts, errors.join("; ").presence ].compact.join(" — ")
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
      @errors = []
    end

    def call
      import("network") { network_client.device_records } if unifi_controller.network_enabled?
      import("protect") { protect_client.device_records } if unifi_controller.protect_enabled?

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

    def build_result
      Result.new(
        devices_created: @devices_created,
        devices_updated: @devices_updated,
        devices_archived: @devices_archived,
        things_created: @things_created,
        things_linked: @things_linked,
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
