module Metrics
  module Collectors
    # What is in the database: users, things, and everything hanging off them.
    module Records
      module_function

      def call(out)
        users(out)
        things(out)
        related(out)
        storage(out)
      end

      def users(out)
        by_provider = User.group(:provider).count.to_h { |provider, count| [ { provider: provider.presence || "local" }, count ] }
        out.gauge("users", "User accounts by sign-in provider.", by_provider)
        out.gauge("users_newest_created_timestamp_seconds", "When the newest user account was created.",
                  User.maximum(:created_at)&.to_f)
      end

      def things(out)
        out.gauge("things", "Things by the integration that created them (none for things added by hand).",
                  Thing.group(:integration_source).count.to_h { |source, count| [ { source: source.presence || "none" }, count ] })
        out.gauge("things_public", "Things visible without signing in.", Thing.where(public_access: true).count)
        out.gauge("things_labelled", "Things marked as labelled.", Thing.where.not(labelled_at: nil).count)
        out.gauge("things_with_template", "Things linked to a template.", Thing.where.not(thing_template_id: nil).count)
        out.gauge("things_newest_updated_timestamp_seconds", "When a thing was last changed.",
                  Thing.maximum(:updated_at)&.to_f)

        qr, nfc, visits = Thing.pick(Arel.sql("COALESCE(SUM(qr_scan_count), 0)"),
                                     Arel.sql("COALESCE(SUM(nfc_scan_count), 0)"),
                                     Arel.sql("COALESCE(SUM(visit_count), 0)"))
        out.gauge("thing_scans", "Label scans recorded across all current things.",
                  { { type: "qr" } => qr.to_i, { type: "nfc" } => nfc.to_i })
        out.gauge("thing_visits", "Page visits recorded across all current things.", visits.to_i)
      end

      def related(out)
        out.gauge("thing_templates", "Thing templates.", ThingTemplate.count)
        out.gauge("thing_links", "Links on things by type.",
                  ThingLink.group(:link_type).count.to_h { |type, count| [ { type: type }, count ] })
        out.gauge("thing_relationships", "Relationships between things.", ThingRelationship.count)
        out.gauge("thing_aliases", "Old keys and slugs kept as aliases.", ThingAlias.count)
        out.gauge("journal_entries", "History entries by event.",
                  JournalEntry.group(:event).count.to_h { |event, count| [ { event: event }, count ] })
        out.gauge("printers", "Printers by type and whether they are enabled.",
                  Printer.group(:printer_type, :enabled).count.to_h do |(type, enabled), count|
                    [ { type: type, enabled: enabled }, count ]
                  end)
      end

      def storage(out)
        out.gauge("storage_blobs", "Uploaded files held in Active Storage.", ActiveStorage::Blob.count)
        out.gauge("storage_bytes", "Bytes of uploaded files held in Active Storage.",
                  ActiveStorage::Blob.sum(:byte_size))
        out.gauge("storage_attachments", "Attached files by what they are attached as.",
                  ActiveStorage::Attachment.group(:record_type, :name).count.to_h do |(record, name), count|
                    [ { record: record, name: name }, count ]
                  end)
      end
    end
  end
end
