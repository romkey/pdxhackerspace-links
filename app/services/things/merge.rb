module Things
  # Folds one thing into another and retires the absorbed thing, keeping its key
  # and slug as aliases so labels and NFC tags printed before the merge still
  # resolve. Field values are decided by the caller (see Things::MergePlan).
  class Merge
    def self.call(target:, source:, attributes: {}, links: {})
      new(target: target, source: source, attributes: attributes, links: links).call
    end

    def initialize(target:, source:, attributes: {}, links: {})
      @target = target
      @source = source
      @attributes = attributes.to_h.stringify_keys
      @links = links.to_h.stringify_keys
    end

    def call
      raise ArgumentError, "a thing can't be merged into itself" if target.id == source.id

      Thing.transaction do
        retired_key = source.key
        retired_slug = source.slug

        reassign_integration_devices
        reassign_aliases
        relationships = capture_relationships
        source.thing_relationships.destroy_all
        move_photos
        move_ar_anchor
        release_unique_columns

        apply_attributes
        apply_standard_links
        move_custom_links
        add_relationships(relationships)

        source.reload.destroy!
        retire_identifiers(retired_key, retired_slug)

        target
      end
    end

    private

    attr_reader :target, :source, :attributes, :links

    # Has to happen before the source is destroyed: Thing#ignore_integration_devices
    # would otherwise mark these devices ignored and unlink them.
    def reassign_integration_devices
      %i[unifi_devices zigbee2mqtt_devices prusa_connect_printers].each do |association|
        source.public_send(association).update_all(thing_id: target.id, updated_at: Time.current)
      end
    end

    # The source may itself have absorbed a merge, so its aliases come along too.
    def reassign_aliases
      ThingAlias.where(thing_id: source.id).update_all(thing_id: target.id, updated_at: Time.current)
    end

    def move_custom_links
      target.links.reload
      existing = target.custom_links.map { |link| [ link.title.to_s, link.url.to_s ] }.to_set
      position = next_custom_link_position

      source.custom_links.select(&:present_link?).each do |link|
        next unless existing.add?([ link.title.to_s, link.url.to_s ])

        link.update!(thing_id: target.id, position: position)
        position += 1
      end
    end

    def next_custom_link_position
      (target.custom_links.map(&:position).compact.max || -1) + 1
    end

    def capture_relationships
      source.thing_relationships.map do |relationship|
        { related_thing_id: relationship.related_thing_id, note: relationship.note }
      end
    end

    def add_relationships(pairs)
      existing = target.thing_relationships.reload.pluck(:related_thing_id).to_set

      pairs.each do |pair|
        next if pair[:related_thing_id] == target.id
        next unless existing.add?(pair[:related_thing_id])

        target.thing_relationships.create!(related_thing_id: pair[:related_thing_id], note: pair[:note])
      end
    end

    # Attachment rows are moved rather than the blobs re-attached. When both things
    # already point at the same blob (as after Duplicate), drop the source row
    # without purging — Active Storage does not reference-count blobs.
    def move_photos
      held = ActiveStorage::Attachment.where(record: target, name: "photos").pluck(:blob_id).to_set

      attachments_for(source, "photos").each do |attachment|
        if held.include?(attachment.blob_id)
          delete_attachment_without_purge(attachment)
        else
          attachment.update_columns(record_id: target.id)
          held.add(attachment.blob_id)
        end
      end
    end

    def move_ar_anchor
      attachment = attachments_for(source, "ar_anchor").first
      return unless attachment

      if target.ar_anchor.attached?
        if target.ar_anchor.blob_id == attachment.blob_id
          delete_attachment_without_purge(attachment)
        end
        return
      end

      attachment.update_columns(record_id: target.id)
    end

    def attachments_for(thing, name)
      ActiveStorage::Attachment.where(record: thing, name: name).to_a
    end

    def delete_attachment_without_purge(attachment)
      ActiveStorage::Attachment.where(id: attachment.id).delete_all
    end

    # Frees the uniquely indexed values so the target can adopt any of them.
    def release_unique_columns
      source.update_columns(slug: nil, ble_beacon_uuid: nil, ieee_address: nil, updated_at: Time.current)
    end

    def apply_attributes
      target.update!(attributes.merge(carried_over_attributes))
    end

    def carried_over_attributes
      {
        "integration_source" => target.integration_source.presence || source.integration_source,
        "qr_scan_count" => target.qr_scan_count + source.qr_scan_count,
        "nfc_scan_count" => target.nfc_scan_count + source.nfc_scan_count,
        "visit_count" => target.visit_count + source.visit_count,
        "labelled_at" => [ target.labelled_at, source.labelled_at ].compact.min
      }
    end

    def apply_standard_links
      links.each do |link_type, values|
        next unless ThingLink::STANDARD_TYPES.key?(link_type)

        write_standard_link(link_type, values["url"].presence, values["note"].presence)
      end
    end

    def write_standard_link(link_type, url, note)
      link = target.links.find_by(link_type: link_type)

      if url.blank? && note.blank?
        link&.destroy
      elsif link
        link.update!(url: url, note: note)
      else
        target.links.create!(link_type: link_type, url: url, note: note)
      end
    end

    def retire_identifiers(key, slug)
      retired_slug = slug.presence
      retired_slug = nil if retired_slug == target.slug

      ThingAlias.create!(thing: target, key: key, slug: retired_slug)
    end
  end
end
