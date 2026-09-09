module PrusaConnect
  # Imports every printer from a Prusa Connect account and populates things from them.
  # Safe to re-run: printers are keyed on their Connect UUID, and printers that
  # disappear from the account are archived rather than deleted.
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
          "#{devices_seen} #{'printer'.pluralize(devices_seen)}",
          ("#{devices_created} new" if devices_created.positive?),
          ("#{things_created} #{'thing'.pluralize(things_created)} created" if things_created.positive?),
          ("#{things_linked} linked" if things_linked.positive?),
          ("#{devices_archived} archived" if devices_archived.positive?)
        ].compact.join(" · ")

        [ counts, errors.join("; ").presence ].compact.join(" — ")
      end
    end

    def self.call(prusa_connect_account:, client: nil)
      new(prusa_connect_account: prusa_connect_account, client: client).call
    end

    def initialize(prusa_connect_account:, client: nil)
      @prusa_connect_account = prusa_connect_account
      @client = client
      @devices_created = 0
      @devices_updated = 0
      @devices_archived = 0
      @things_created = 0
      @things_linked = 0
      @errors = []
    end

    def call
      response = client.printer_records
      @errors.concat(response.errors)
      seen = response.records.filter_map { |record| upsert(record) }
      archive_missing(seen)

      build_result.tap { |result| record_sync(result) }
    rescue Client::Error => error
      @errors << error.message
      build_result.tap { |result| record_sync(result) }
    end

    private

    attr_reader :prusa_connect_account

    def client
      @client ||= prusa_connect_account.client
    end

    def upsert(record)
      printer = prusa_connect_account.prusa_connect_printers.find_or_initialize_by(
        external_id: record.external_id
      )
      created = printer.new_record?
      now = Time.current

      printer.assign_attributes(record.to_attributes.merge(last_seen_at: now, archived_at: nil))
      printer.first_seen_at ||= now
      printer.save!
      created ? @devices_created += 1 : @devices_updated += 1

      sync_thing(printer)
      printer.id
    rescue ActiveRecord::RecordInvalid => error
      label = record.name.presence || record.external_id
      @errors << "#{label}: #{error.record.errors.full_messages.to_sentence}"
      printer&.id
    end

    def sync_thing(printer)
      case SyncThing.call(
        prusa_connect_printer: printer,
        auto_create: prusa_connect_account.auto_create_things?
      )
      when :created then @things_created += 1
      when :linked then @things_linked += 1
      end
    end

    def archive_missing(seen_ids)
      scope = prusa_connect_account.prusa_connect_printers.active
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
      prusa_connect_account.reload.update!(
        last_synced_at: Time.current,
        last_sync_status: result.status,
        last_sync_message: result.summary
      )
    end
  end
end
