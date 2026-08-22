module Things
  # Subclasses rather than using a Data.define block so the constants below are
  # scoped here instead of leaking into Things and colliding across services.
  class IndexQuery < Data.define(:scope, :sort, :direction, :total_count, :filters)
    PUBLIC_SORTS = %w[name hostname ip_address links photos].freeze
    ADMIN_SORTS = %w[qr nfc visits].freeze
    SORTS = (PUBLIC_SORTS + ADMIN_SORTS).freeze
    DEFAULT_SORT = "name"

    def self.call(search: nil, sort: DEFAULT_SORT, direction: nil, admin: false, filters: {})
      allowed_sorts = admin ? SORTS : PUBLIC_SORTS
      sort = allowed_sorts.include?(sort.to_s) ? sort.to_s : DEFAULT_SORT
      direction = normalized_direction(sort, direction)
      filters = IndexFilters.parse(filters)

      scope = Thing.search(search)
      scope = IndexFilters.apply(scope, filters)
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

    def self.with_counts(scope)
      scope.select("things.*")
           .select(Arel.sql("#{CountSql::LINKS} AS links_count"))
           .select(Arel.sql("#{CountSql::PHOTOS} AS photos_count"))
    end

    def self.apply_sort(scope, sort, direction)
      dir = direction.to_s.upcase
      tie_break = Arel.sql("things.name ASC")

      case sort
      when "hostname"
        scope.reorder(Arel.sql("things.hostname #{dir} NULLS LAST"), tie_break)
      when "ip_address"
        scope.reorder(Arel.sql("things.ip_address #{dir} NULLS LAST"), tie_break)
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
      else
        scope.reorder(name: direction)
      end
    end

    def self.normalized_direction(sort, direction)
      return :desc if direction.to_s.downcase == "desc"
      return :asc if direction.to_s.downcase == "asc"

      %w[name hostname ip_address].include?(sort) ? :asc : :desc
    end
    private_class_method :normalized_direction
  end
end
