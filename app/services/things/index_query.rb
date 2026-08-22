module Things
  # Subclasses rather than using a Data.define block so the constants below are
  # scoped here instead of leaking into Things and colliding across services.
  class IndexQuery < Data.define(:scope, :sort, :direction, :total_count, :filters)
    PUBLIC_SORTS = %w[name hostname ip_address manufacturer model integration links photos].freeze
    ADMIN_SORTS = %w[labelled qr nfc visits].freeze
    SORTS = (PUBLIC_SORTS + ADMIN_SORTS).freeze
    DEFAULT_SORT = "name"
    ASC_DEFAULT_SORTS = %w[name hostname ip_address manufacturer model integration].freeze

    def self.call(search: nil, sort: DEFAULT_SORT, direction: nil, admin: false, filters: {})
      allowed_sorts = admin ? SORTS : PUBLIC_SORTS
      sort = allowed_sorts.include?(sort.to_s) ? sort.to_s : DEFAULT_SORT
      direction = normalized_direction(sort, direction)
      filters = IndexFilters.parse(filters)

      scope = filtered_scope(search: search, filters: filters)
      total_count = scope.distinct.count(:id)
      scope = with_counts(scope)
      scope = apply_sort(scope, sort, direction)

      new(
        scope: scope,
        sort: sort,
        direction: direction.to_s,
        total_count: total_count,
        filters: filters
      )
    end

    def self.filtered_scope(search: nil, filters: {})
      scope = Thing.search(search)
      parsed = filters.is_a?(IndexFilters) ? filters : IndexFilters.parse(filters)
      IndexFilters.apply(scope, parsed)
    end

    def self.with_counts(scope)
      scope.select("things.*")
           .select(Arel.sql("#{CountSql::LINKS} AS links_count"))
           .select(Arel.sql("#{CountSql::PHOTOS} AS photos_count"))
    end

    def self.apply_sort(scope, sort, direction)
      dir = direction.to_s.upcase
      tie_break = Arel.sql("things.name ASC")

      case sort
      when "hostname", "ip_address", "manufacturer", "model", "integration"
        column = sort == "integration" ? "integration_source" : "things.#{sort}"
        scope.reorder(Arel.sql("#{column} #{dir} NULLS LAST"), tie_break)
      when "links"
        scope.reorder(Arel.sql("#{CountSql::LINKS} #{dir}"), tie_break)
      when "photos"
        scope.reorder(Arel.sql("#{CountSql::PHOTOS} #{dir}"), tie_break)
      when "qr"
        scope.reorder(qr_scan_count: direction, name: :asc)
      when "nfc"
        scope.reorder(nfc_scan_count: direction, name: :asc)
      when "visits"
        scope.reorder(visit_count: direction, name: :asc)
      when "labelled"
        scope.reorder(Arel.sql("things.labelled_at #{dir} NULLS LAST"), tie_break)
      else
        scope.reorder(name: direction)
      end
    end

    def self.normalized_direction(sort, direction)
      return :desc if direction.to_s.downcase == "desc"
      return :asc if direction.to_s.downcase == "asc"

      ASC_DEFAULT_SORTS.include?(sort) ? :asc : :desc
    end
    private_class_method :normalized_direction
  end
end
