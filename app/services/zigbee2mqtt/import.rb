module Zigbee2mqtt
  class Import
    Result = Data.define(
      :devices_created,
      :devices_updated,
      :devices_archived,
      :devices_skipped,
      :skipped_unknown_last_seen,
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
          ("#{devices_archived} archived" if devices_archived.positive?),
          ("#{devices_skipped} skipped" if devices_skipped.positive?)
        ].compact.join(" · ")

        hints = []
        if skipped_unknown_last_seen.positive?
          hints << "#{skipped_unknown_last_seen} skipped for unknown last_seen — enable advanced.last_seen and retain in Zigbee2MQTT"
        end

        message = [ counts, errors.join("; ").presence, hints.join("; ").presence ].compact.join(" — ")
        message.presence || "No devices imported"
      end
    end

    def self.call(zigbee2mqtt_bridge:, client: nil)
      new(zigbee2mqtt_bridge: zigbee2mqtt_bridge, client: client).call
    end

    def initialize(zigbee2mqtt_bridge:, client: nil)
      @bridge = zigbee2mqtt_bridge
      @client = client
      @devices_created = 0
      @devices_updated = 0
      @devices_archived = 0
      @devices_skipped = 0
      @skipped_unknown_last_seen = 0
      @things_created = 0
      @things_linked = 0
      @errors = []
    end

    def call
      seen = []
      present_ieee_addresses = []

      client.device_records.each do |record|
        next if record.ieee_address.blank?

        present_ieee_addresses << record.ieee_address
        next unless importable?(record)

        device_id = upsert(record)
        seen << device_id if device_id
      end

      archive_missing(present_ieee_addresses)

      build_result.tap { |result| record_sync(result) }
    rescue Client::Error => error
      @errors << error.message
      build_result.tap { |result| record_sync(result) }
    end

    private

    attr_reader :bridge

    def client
      @client ||= Client.for(bridge)
    end

    def importable?(record)
      if bridge.skip_disabled_devices? && record.disabled
        @devices_skipped += 1
        return false
      end

      return true if bridge.last_seen_limit_days.blank?

      last_seen = record.reported_last_seen_at
      if last_seen.blank?
        unless bridge.import_unknown_last_seen?
          @devices_skipped += 1
          @skipped_unknown_last_seen += 1
          return false
        end
        return true
      end

      if last_seen < bridge.last_seen_limit_days.days.ago
        @devices_skipped += 1
        return false
      end

      true
    end

    def upsert(record)
      return nil if record.ieee_address.blank?

      device = bridge.zigbee2mqtt_devices.find_or_initialize_by(ieee_address: record.ieee_address)
      created = device.new_record?
      now = Time.current

      device.assign_attributes(record.to_attributes.merge(last_seen_at: now, archived_at: nil))
      device.first_seen_at ||= now
      device.save!
      created ? @devices_created += 1 : @devices_updated += 1

      sync_thing(device)
      device.id
    rescue ActiveRecord::RecordInvalid => error
      label = record.friendly_name.presence || record.ieee_address
      @errors << "#{label}: #{error.record.errors.full_messages.to_sentence}"
      device&.id
    end

    def sync_thing(device)
      case Integrations::SyncThing.call(integration_device: device, auto_create: bridge.auto_create_things?)
      when :created then @things_created += 1
      when :linked then @things_linked += 1
      end
    end

    def archive_missing(present_ieee_addresses)
      return if present_ieee_addresses.empty?

      scope = bridge.zigbee2mqtt_devices.active.where.not(ieee_address: present_ieee_addresses)

      @devices_archived += scope.update_all(archived_at: Time.current, updated_at: Time.current)
    end

    def build_result
      Result.new(
        devices_created: @devices_created,
        devices_updated: @devices_updated,
        devices_archived: @devices_archived,
        devices_skipped: @devices_skipped,
        skipped_unknown_last_seen: @skipped_unknown_last_seen,
        things_created: @things_created,
        things_linked: @things_linked,
        errors: @errors
      )
    end

    def record_sync(result)
      bridge.record_sync!(status: result.status, message: result.summary)
    end
  end
end
