module ThingsHelper
  THINGS_INDEX_FILTER_GROUPS = [
    { key: :links, label: "Links" },
    { key: :photos, label: "Photos" },
    { key: :ip_address, label: "IP address" },
    { key: :hostname, label: "Hostname" },
    { key: :mac_address, label: "MAC address" },
    { key: :ar_marker, label: "AR marker" },
    { key: :wiki, label: "Wiki" },
    { key: :slack, label: "Slack" },
    { key: :where, label: "Where" },
    { key: :asset, label: "Asset" },
    { key: :url, label: "URL" }
  ].freeze

  def things_index_filter_groups
    THINGS_INDEX_FILTER_GROUPS
  end

  def things_sort_link(label, column)
    active = @things_index.sort == column.to_s
    next_direction = if active
      @things_index.direction == "desc" ? "asc" : "desc"
    elsif %w[name hostname ip_address].include?(column.to_s)
      "asc"
    else
      "desc"
    end
    icon = if active
      tag.i(class: "bi bi-chevron-#{@things_index.direction == "asc" ? "up" : "down"} text-11")
    end

    link_to things_path(things_index_params(sort: column, direction: next_direction)),
            class: class_names("scan-visits-sort text-reset text-decoration-none", "fw-medium" => active) do
      safe_join([ label, icon ].compact, " ")
    end
  end

  def things_filter_chip(label, key, value)
    filters = @things_index.filters.values.dup
    current = filters[key.to_sym]

    if value.nil?
      active = current.nil?
      filters.delete(key.to_sym)
    else
      active = current == value
      filters[key.to_sym] = value
    end

    link_to label,
            things_path(things_index_params(filter: filters)),
            class: class_names("filter-chip", active: active)
  end

  def things_clear_filters_path
    things_path(things_index_params(filter: {}))
  end

  def things_index_params(overrides = {})
    params = {}
    if overrides.key?(:q)
      params[:q] = overrides[:q] if overrides[:q].present?
    elsif @search_query.present?
      params[:q] = @search_query
    end
    params[:sort] = overrides.fetch(:sort, @things_index.sort)
    params[:direction] = overrides.fetch(:direction, @things_index.direction)
    params[:page] = overrides[:page] if overrides.key?(:page)

    filter_params = if overrides.key?(:filter)
      overrides[:filter].to_h.stringify_keys.select { |_, value| value.present? }
    elsif @things_index.filters.active?
      @things_index.filters.to_params
    end
    params[:filter] = filter_params if filter_params.present?

    params
  end
end
