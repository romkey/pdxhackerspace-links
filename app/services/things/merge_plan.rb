module Things
  # Compares the two things about to be merged and works out, field by field,
  # whether the value is unchanged, filled in from the thing being absorbed, or
  # genuinely in conflict and so needs a decision from whoever is merging.
  class MergePlan
    Field = Struct.new(:name, :label, :kind, :target_value, :source_value, keyword_init: true) do
      def state
        return :same if same?
        return :from_source if empty?(target_value)
        return :target_only if empty?(source_value)

        :conflict
      end

      def conflict?
        state == :conflict
      end

      def from_source?
        state == :from_source
      end

      def default_value
        from_source? ? source_value : target_value
      end

      def boolean?
        kind == :boolean
      end

      def textarea?
        kind == :textarea
      end

      def same?
        comparable(target_value) == comparable(source_value)
      end

      private

      # A boolean is never empty — false is a real answer, not a missing one.
      def empty?(value)
        return false if boolean?

        value.to_s.strip.empty?
      end

      def comparable(value)
        return ActiveModel::Type::Boolean.new.cast(value) ? "1" : "0" if boolean?

        value.to_s.strip
      end
    end

    THING_GROUPS = [
      {
        label: "Identity",
        fields: [
          [ :name, "Name", :text ],
          [ :label_name, "Label name", :text ],
          [ :owner, "Owner", :text ],
          [ :slug, "Slug", :text ],
          [ :public_access, "Public", :boolean ]
        ]
      },
      {
        label: "Hardware",
        fields: [
          [ :manufacturer, "Manufacturer", :text ],
          [ :model, "Model", :text ],
          [ :serial_number, "Serial number", :text ],
          [ :manufacturer_url, "Manufacturer link", :text ]
        ]
      },
      {
        label: "Network and radios",
        fields: [
          [ :ip_address, "IP address", :text ],
          [ :hostname, "Hostname", :text ],
          [ :ieee_address, "IEEE address", :text ],
          [ :ble_beacon_uuid, "BLE beacon UUID", :text ]
        ]
      },
      {
        label: "Description and notes",
        fields: [
          [ :description, "Description", :textarea ],
          [ :notes, "Notes", :textarea ],
          [ :ar_anchor_note, "AR marker note", :text ]
        ]
      }
    ].freeze

    THING_FIELD_NAMES = THING_GROUPS.flat_map { |group| group[:fields].map { |name, _label, _kind| name.to_s } }.freeze

    LINKS_GROUP_LABEL = "Standard links".freeze

    def self.link_field_name(link_type, attribute)
      "link_#{link_type}_#{attribute}"
    end

    def initialize(target:, source:)
      @target = target
      @source = source
    end

    attr_reader :target, :source

    def groups
      @groups ||= build_thing_groups + [ build_links_group ]
    end

    def fields
      @fields ||= groups.flat_map { |group| group[:fields] }
    end

    def conflicts
      @conflicts ||= fields.select(&:conflict?)
    end

    def conflicts?
      conflicts.any?
    end

    def carried_over_fields
      @carried_over_fields ||= fields.select(&:from_source?)
    end

    # Only fields the form actually offered a control for can be overridden;
    # everything else falls back to the value this plan worked out.
    def resolve(submitted = {})
      chosen = submitted.to_h.stringify_keys.slice(*conflicts.map { |field| field.name.to_s })
      values = defaults.merge(chosen)

      {
        attributes: values.slice(*THING_FIELD_NAMES),
        links: link_values(values)
      }
    end

    def defaults
      fields.to_h { |field| [ field.name.to_s, field.default_value ] }
    end

    def custom_links
      @custom_links ||= source.custom_links.select(&:present_link?)
    end

    def photo_count
      @photo_count ||= source.photos.count
    end

    def ar_anchor_carried_over?
      source.ar_anchor.attached? && !target.ar_anchor.attached?
    end

    def relationship_additions
      @relationship_additions ||= begin
        existing = target.thing_relationships.pluck(:related_thing_id).to_set
        source.thing_relationships.reject do |relationship|
          relationship.related_thing_id == target.id || existing.include?(relationship.related_thing_id)
        end
      end
    end

    def integration_device_count
      @integration_device_count ||= source.unifi_devices.count +
                                    source.zigbee2mqtt_devices.count +
                                    source.prusa_connect_printers.count
    end

    def scan_total
      source.scan_total_count
    end

    def visit_total
      source.visit_count
    end

    def retired_key
      source.key
    end

    def retired_slug
      slug = source.slug
      return nil if slug.blank?
      return nil if defaults["slug"].to_s == slug

      slug
    end

    private

    def build_thing_groups
      THING_GROUPS.map do |group|
        {
          label: group[:label],
          fields: group[:fields].map { |name, label, kind| thing_field(name, label, kind) }
        }
      end
    end

    def thing_field(name, label, kind)
      Field.new(
        name: name.to_s,
        label: label,
        kind: kind,
        target_value: target.public_send(name),
        source_value: source.public_send(name)
      )
    end

    # Standard links are unique per thing, so their values have to be resolved
    # like any other field rather than moved across.
    def build_links_group
      fields = ThingLink::STANDARD_TYPES.flat_map do |link_type, title|
        target_link = standard_link(target, link_type)
        source_link = standard_link(source, link_type)

        [
          link_field(link_type, "url", "#{title} link", target_link, source_link),
          link_field(link_type, "note", "#{title} note", target_link, source_link)
        ]
      end

      { label: LINKS_GROUP_LABEL, fields: fields }
    end

    # Deliberately not Thing#link_for, which builds a blank link as a side effect.
    def standard_link(thing, link_type)
      thing.links.detect { |link| link.link_type == link_type }
    end

    def link_field(link_type, attribute, label, target_link, source_link)
      Field.new(
        name: self.class.link_field_name(link_type, attribute),
        label: label,
        kind: :text,
        target_value: target_link&.public_send(attribute),
        source_value: source_link&.public_send(attribute)
      )
    end

    def link_values(values)
      ThingLink::STANDARD_TYPES.keys.to_h do |link_type|
        [
          link_type,
          {
            "url" => values[self.class.link_field_name(link_type, "url")],
            "note" => values[self.class.link_field_name(link_type, "note")]
          }
        ]
      end
    end
  end
end
