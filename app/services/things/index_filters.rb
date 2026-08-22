module Things
  IndexFilters = Data.define(:values) do
    KEYS = %i[
      links photos ip_address hostname mac_address ar_marker
      wiki slack where asset url
    ].freeze

    def self.parse(raw)
      hash = if raw.is_a?(ActionController::Parameters)
        raw.permit(*KEYS.map(&:to_s)).to_h
      else
        raw.to_h
      end

      values = {}
      hash.each do |key, value|
        sym_key = key.to_sym
        next unless KEYS.include?(sym_key)

        normalized = value.to_s.downcase
        values[sym_key] = normalized if %w[yes no].include?(normalized)
      end

      new(values: values)
    end

    def self.apply(scope, filters)
      filters.values.reduce(scope) do |current_scope, (key, value)|
        apply_filter(current_scope, key, value)
      end
    end

    def self.apply_filter(scope, key, value)
      case key
      when :links
        apply_count_filter(scope, CountSql::LINKS, value)
      when :photos
        apply_count_filter(scope, CountSql::PHOTOS, value)
      when :ip_address, :hostname, :mac_address
        apply_presence_filter(scope, key, value)
      when :ar_marker
        apply_exists_filter(scope, CountSql::AR_MARKER, value)
      when :wiki, :slack, :where, :asset
        apply_link_type_filter(scope, key.to_s, value)
      when :url
        apply_link_type_filter(scope, "custom", value)
      else
        scope
      end
    end
    private_class_method :apply_filter

    def self.apply_count_filter(scope, count_sql, value)
      condition = value == "yes" ? "> 0" : "= 0"
      scope.where(Arel.sql("#{count_sql} #{condition}"))
    end
    private_class_method :apply_count_filter

    def self.apply_presence_filter(scope, column, value)
      if value == "yes"
        scope.where.not(column => [ nil, "" ])
      else
        scope.where(column => [ nil, "" ])
      end
    end
    private_class_method :apply_presence_filter

    def self.apply_exists_filter(scope, exists_sql, value)
      if value == "yes"
        scope.where("EXISTS #{exists_sql}")
      else
        scope.where("NOT EXISTS #{exists_sql}")
      end
    end
    private_class_method :apply_exists_filter

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
      values.size
    end

    def active?
      values.any?
    end

    def [](key)
      values[key.to_sym]
    end

    def to_params
      values.transform_keys(&:to_s)
    end
  end
end
