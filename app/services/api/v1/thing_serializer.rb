module Api
  module V1
    # Everything the API says about a thing. Fields are listed explicitly so a
    # new column is never published by accident, and integration records leave
    # out their raw payloads.
    class ThingSerializer
      FIELDS = %i[
        id key slug name label_name description notes owner
        manufacturer model serial_number manufacturer_url
        ip_address reserved_ip_address network_name hostname ieee_address ble_beacon_uuid
        ar_anchor_note public_access training_required integration_source labelled_at
        visit_count qr_scan_count nfc_scan_count created_at updated_at
      ].freeze

      UNIFI_DEVICE_FIELDS = %i[
        id source kind name model ieee_address ip_address firmware_version state
        site_name archived_at first_seen_at last_seen_at
      ].freeze

      UNIFI_HOST_FIELDS = %i[
        id name hostname note manufacturer ieee_address ip_address reserved_ip_address
        connection_type network_name vlan ssid radio wifi_standard channel signal satisfaction
        uplink_name uplink_ieee_address switch_port online guest blocked
        site_name archived_at connected_at first_seen_at last_seen_at
      ].freeze

      ZIGBEE2MQTT_DEVICE_FIELDS = %i[
        id friendly_name ieee_address device_type manufacturer model model_description
        power_source software_build_id date_code supported disabled
        archived_at first_seen_at last_seen_at reported_last_seen_at
      ].freeze

      PRUSA_CONNECT_PRINTER_FIELDS = %i[
        id name printer_model printer_type_name serial_number firmware hostname ieee_address
        state location team_name archived_at first_seen_at last_seen_at
      ].freeze

      PRELOADS = [
        :links,
        :thing_aliases,
        :thing_template,
        :unifi_devices,
        :unifi_hosts,
        :zigbee2mqtt_devices,
        :prusa_connect_printers,
        { thing_relationships: :related_thing },
        { photos_attachments: :blob },
        { ar_anchor_attachment: :blob }
      ].freeze

      def self.preload(things)
        ActiveRecord::Associations::Preloader.new(records: things.to_a, associations: PRELOADS).call
        things
      end

      # urls responds to the app's route helpers (a controller).
      def initialize(thing, urls:)
        @thing = thing
        @urls = urls
      end

      def as_json(*)
        thing.slice(*FIELDS).merge(
          "url" => urls.thing_url(thing),
          "short_url" => ShortUrl.display_url(thing),
          "template" => template,
          "links" => links,
          "related_things" => related_things,
          "aliases" => aliases,
          "photos" => thing.photos.map { |photo| attachment(photo) },
          "ar_anchor" => (attachment(thing.ar_anchor) if thing.ar_anchor.attached?),
          "integrations" => integrations
        )
      end

      private

      attr_reader :thing, :urls

      def template
        return unless thing.thing_template

        { "id" => thing.thing_template.id, "name" => thing.thing_template.name }
      end

      def links
        thing.links
             .select { |link| link.url.present? || link.note.present? }
             .sort_by { |link| [ link.standard? ? 0 : 1, link.position || 0, link.display_title.to_s ] }
             .map do |link|
          {
            "id" => link.id,
            "type" => link.link_type,
            "title" => link.display_title,
            "url" => link.url.presence,
            "note" => link.note.presence,
            "position" => link.position,
            "created_at" => link.created_at,
            "updated_at" => link.updated_at
          }
        end
      end

      def related_things
        thing.thing_relationships.sort_by { |rel| rel.related_thing.name.downcase }.map do |rel|
          related = rel.related_thing
          {
            "id" => related.id,
            "key" => related.key,
            "slug" => related.slug,
            "name" => related.name,
            "url" => urls.thing_url(related),
            "note" => rel.note.presence
          }
        end
      end

      def aliases
        thing.thing_aliases.map { |entry| { "key" => entry.key, "slug" => entry.slug } }
      end

      def attachment(file)
        {
          "filename" => file.filename.to_s,
          "content_type" => file.content_type,
          "byte_size" => file.byte_size,
          "url" => urls.rails_blob_url(file)
        }
      end

      def integrations
        {
          "unifi_devices" => thing.unifi_devices.map { |record| record.slice(*UNIFI_DEVICE_FIELDS) },
          "unifi_hosts" => thing.unifi_hosts.map { |record| record.slice(*UNIFI_HOST_FIELDS) },
          "zigbee2mqtt_devices" => thing.zigbee2mqtt_devices.map { |record| record.slice(*ZIGBEE2MQTT_DEVICE_FIELDS) },
          "prusa_connect_printers" => thing.prusa_connect_printers.map { |record| record.slice(*PRUSA_CONNECT_PRINTER_FIELDS) }
        }
      end
    end
  end
end
