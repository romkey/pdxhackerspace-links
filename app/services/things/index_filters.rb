module Things
  class IndexFilters < Data.define(:values, :sources, :excluded_sources)
    KEYS = %i[
      links photos ip_address reserved_ip_address wifi wired online hostname ieee_address ar_marker labelled
      wiki slack where url
    ].freeze

    def self.parse(raw)
      hash = if raw.is_a?(ActionController::Parameters)
        raw.permit(*KEYS.map(&:to_s), integration: [], integration_exclude: []).to_h
      else
        raw.to_h.stringify_keys
      end

      values = {}
      hash.except("integration", "integration_exclude").each do |key, value|
        sym_key = key.to_sym
        next unless KEYS.include?(sym_key)

        normalized = value.to_s.downcase
        values[sym_key] = normalized if %w[yes no].include?(normalized)
      end

      sources = parse_sources(hash["integration"])
      excluded_sources = parse_sources(hash["integration_exclude"]) - sources

      new(values: values, sources: sources, excluded_sources: excluded_sources)
    end

    def self.parse_sources(raw)
      Array(raw).map(&:to_s).select { |key| Integrations::Registry.filter_keys.include?(key) }.uniq
    end
    private_class_method :parse_sources

    def self.apply(scope, filters)
      scope = filters.values.reduce(scope) do |current_scope, (key, value)|
        apply_filter(current_scope, key, value)
      end

      scope = apply_integration_sources(scope, filters.sources)
      apply_integration_exclusions(scope, filters.excluded_sources)
    end

    def self.apply_filter(scope, key, value)
      case key
      when :links
        apply_links_count_filter(scope, value)
      when :photos
        apply_photos_count_filter(scope, value)
      when :ip_address, :reserved_ip_address, :hostname, :ieee_address
        apply_presence_filter(scope, key, value)
      when :wifi
        apply_host_filter(scope, UnifiHost.wireless, value)
      when :wired
        apply_host_filter(scope, UnifiHost.wired, value)
      when :online
        apply_host_filter(scope, UnifiHost.online, value)
      when :ar_marker
        apply_ar_marker_filter(scope, value)
      when :labelled
        apply_timestamp_filter(scope, :labelled_at, value)
      when :wiki, :slack, :where
        apply_link_type_filter(scope, key.to_s, value)
      when :url
        apply_link_type_filter(scope, "custom", value)
      else
        scope
      end
    end
    private_class_method :apply_filter

    def self.apply_integration_sources(scope, sources)
      return scope if sources.empty?

      clauses = []
      real_sources = sources - [ Integrations::Registry::FILTER_NONE ]
      clauses << scope.where(integration_source: real_sources) if real_sources.any?
      clauses << scope.where(integration_source: nil) if sources.include?(Integrations::Registry::FILTER_NONE)

      clauses.reduce { |combined, clause| combined.or(clause) }
    end
    private_class_method :apply_integration_sources

    # NOT IN drops NULLs, so things with no integration have to be let back in
    # explicitly unless "none" is itself excluded.
    def self.apply_integration_exclusions(scope, excluded_sources)
      return scope if excluded_sources.empty?

      column = Thing.arel_table[:integration_source]
      real_sources = excluded_sources - [ Integrations::Registry::FILTER_NONE ]
      scope = scope.where(column.eq(nil).or(column.not_in(real_sources))) if real_sources.any?
      scope = scope.where.not(integration_source: nil) if excluded_sources.include?(Integrations::Registry::FILTER_NONE)
      scope
    end
    private_class_method :apply_integration_exclusions

    def self.apply_links_count_filter(scope, value)
      link_scope = ThingLink.where("thing_links.thing_id = things.id")
                            .where.not(url: [ nil, "" ])

      if value == "yes"
        scope.where("EXISTS (?)", link_scope.select(1))
      else
        scope.where("NOT EXISTS (?)", link_scope.select(1))
      end
    end
    private_class_method :apply_links_count_filter

    def self.apply_photos_count_filter(scope, value)
      photo_scope = ActiveStorage::Attachment.where(record_type: "Thing", name: "photos")
                                             .where("active_storage_attachments.record_id = things.id")

      if value == "yes"
        scope.where("EXISTS (?)", photo_scope.select(1))
      else
        scope.where("NOT EXISTS (?)", photo_scope.select(1))
      end
    end
    private_class_method :apply_photos_count_filter

    # Matches things through the UniFi hosts linked to them. Archived hosts no
    # longer describe how anything connects, so they are left out.
    def self.apply_host_filter(scope, host_scope, value)
      host_scope = host_scope.active.where("unifi_hosts.thing_id = things.id")

      if value == "yes"
        scope.where("EXISTS (?)", host_scope.select(1))
      else
        scope.where("NOT EXISTS (?)", host_scope.select(1))
      end
    end
    private_class_method :apply_host_filter

    def self.apply_presence_filter(scope, column, value)
      if value == "yes"
        scope.where.not(column => [ nil, "" ])
      else
        scope.where(column => [ nil, "" ])
      end
    end
    private_class_method :apply_presence_filter

    def self.apply_timestamp_filter(scope, column, value)
      if value == "yes"
        scope.where.not(column => nil)
      else
        scope.where(column => nil)
      end
    end
    private_class_method :apply_timestamp_filter

    def self.apply_ar_marker_filter(scope, value)
      attachment_scope = ActiveStorage::Attachment.where(record_type: "Thing", name: "ar_anchor")
                                                  .where("active_storage_attachments.record_id = things.id")

      if value == "yes"
        scope.where("EXISTS (?)", attachment_scope.select(1))
      else
        scope.where("NOT EXISTS (?)", attachment_scope.select(1))
      end
    end
    private_class_method :apply_ar_marker_filter

    def self.apply_link_type_filter(scope, link_type, value)
      link_scope = ThingLink.where("thing_links.thing_id = things.id")
                            .where(link_type: link_type)
                            .where.not(url: [ nil, "" ])

      if value == "yes"
        scope.where("EXISTS (?)", link_scope.select(1))
      else
        scope.where("NOT EXISTS (?)", link_scope.select(1))
      end
    end
    private_class_method :apply_link_type_filter

    def active_count
      values.size + (integration_filtered? ? 1 : 0)
    end

    def active?
      values.any? || integration_filtered?
    end

    def integration_filtered?
      sources.any? || excluded_sources.any?
    end

    def [](key)
      values[key.to_sym]
    end

    # "yes" when only things from this integration are shown, "no" when they
    # are excluded, nil otherwise — the same states the other filters use.
    def integration_state(key)
      if sources.include?(key.to_s)
        "yes"
      elsif excluded_sources.include?(key.to_s)
        "no"
      end
    end

    def to_params
      params = values.transform_keys(&:to_s)
      params["integration"] = sources if sources.any?
      params["integration_exclude"] = excluded_sources if excluded_sources.any?
      params
    end
  end
end
