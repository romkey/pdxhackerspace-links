module Things
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
      tie_break = Arel.sql("things.name ASC")

      case sort
      when "hostname"
        if direction == :desc
          scope.reorder(Arel.sql("things.hostname DESC NULLS LAST"), tie_break)
        else
          scope.reorder(Arel.sql("things.hostname ASC NULLS LAST"), tie_break)
        end
      when "ip_address"
        if direction == :desc
          scope.reorder(Arel.sql("things.ip_address DESC NULLS LAST"), tie_break)
        else
          scope.reorder(Arel.sql("things.ip_address ASC NULLS LAST"), tie_break)
        end
      when "manufacturer"
        if direction == :desc
          scope.reorder(Arel.sql("things.manufacturer DESC NULLS LAST"), tie_break)
        else
          scope.reorder(Arel.sql("things.manufacturer ASC NULLS LAST"), tie_break)
        end
      when "model"
        if direction == :desc
          scope.reorder(Arel.sql("things.model DESC NULLS LAST"), tie_break)
        else
          scope.reorder(Arel.sql("things.model ASC NULLS LAST"), tie_break)
        end
      when "integration"
        if direction == :desc
          scope.reorder(Arel.sql("integration_source DESC NULLS LAST"), tie_break)
        else
          scope.reorder(Arel.sql("integration_source ASC NULLS LAST"), tie_break)
        end
      when "links"
        if direction == :desc
          scope.reorder(Arel.sql("#{CountSql::LINKS} DESC"), tie_break)
        else
          scope.reorder(Arel.sql("#{CountSql::LINKS} ASC"), tie_break)
        end
      when "photos"
        if direction == :desc
          scope.reorder(Arel.sql("#{CountSql::PHOTOS} DESC"), tie_break)
        else
          scope.reorder(Arel.sql("#{CountSql::PHOTOS} ASC"), tie_break)
        end
      when "qr"
        scope.reorder(qr_scan_count: direction, name: :asc)
      when "nfc"
        scope.reorder(nfc_scan_count: direction, name: :asc)
      when "visits"
        scope.reorder(visit_count: direction, name: :asc)
      when "labelled"
        if direction == :desc
          scope.reorder(Arel.sql("things.labelled_at DESC NULLS LAST"), tie_break)
        else
          scope.reorder(Arel.sql("things.labelled_at ASC NULLS LAST"), tie_break)
        end
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
