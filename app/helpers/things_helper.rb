module ThingsHelper
  THINGS_INDEX_FILTER_GROUPS = [
    { key: :links, label: "Links" },
    { key: :photos, label: "Photos" },
    { key: :ip_address, label: "IP address" },
    { key: :hostname, label: "Hostname" },
    { key: :ieee_address, label: "IEEE address" },
    { key: :ar_marker, label: "AR marker" },
    { key: :labelled, label: "Labelled", admin_only: true },
    { key: :wiki, label: "Wiki" },
    { key: :slack, label: "Slack" },
    { key: :where, label: "Where" },
    { key: :asset, label: "Asset" },
    { key: :url, label: "URL" }
  ].freeze

  THINGS_FILTER_CYCLE = { nil => "yes", "yes" => "no", "no" => nil }.freeze
  THINGS_FILTER_STATES = { nil => "any", "yes" => "has", "no" => "none" }.freeze

  THINGS_DEFAULT_COLUMNS = %w[name manufacturer model integration links photos].freeze
  THINGS_OPTIONAL_COLUMNS = %w[hostname ip_address labelled visits nfc qr].freeze
  THINGS_ALL_COLUMNS = (THINGS_DEFAULT_COLUMNS + THINGS_OPTIONAL_COLUMNS).freeze
  THINGS_COLUMN_LABELS = {
    "name" => "Name",
    "manufacturer" => "Manufacturer",
    "model" => "Model",
    "integration" => "Integration",
    "links" => "Links",
    "photos" => "Photos",
    "hostname" => "Hostname",
    "ip_address" => "IP address",
    "labelled" => "Labelled",
    "visits" => "Views",
    "nfc" => "NFC",
    "qr" => "QR"
  }.freeze

  def things_index_filter_groups
    THINGS_INDEX_FILTER_GROUPS.select { |group| !group[:admin_only] || can_manage_things? }
  end

  def things_labelled_cell(thing)
    if thing.labelled?
      tag.span(class: "status-dot status-success", title: thing.labelled_at.to_fs(:long))
    else
      tag.span("—", class: "text-secondary")
    end
  end

  def things_printers_data(printers)
    printers.map do |printer|
      {
        id: printer.id,
        name: printer.name,
        cable_tag_capable: printer.cable_tag_capable?,
        command: printer.command?
      }
    end
  end

  def things_index_container_data
    {
      controller: "thing-selection print-dialog",
      thing_selection_total_count_value: @pagy.count,
      thing_selection_filter_params_value: things_bulk_filter_params,
      print_dialog_printers_value: (can_manage_things? ? things_printers_data(@printers) : []),
      print_dialog_bulk_print_url_value: bulk_print_things_path,
      print_dialog_bulk_preview_url_value: bulk_label_preview_things_path
    }
  end

  def things_show_container_data
    {
      controller: "print-dialog",
      print_dialog_printers_value: (can_manage_things? ? things_printers_data(@printers) : []),
      print_dialog_bulk_print_url_value: bulk_print_things_path
    }
  end

  def things_print_dialog_trigger_data(action: "print-dialog#open", **extra)
    {
      bs_toggle: "modal",
      bs_target: "#print-label-dialog",
      action: action
    }.merge(extra)
  end

  def things_bulk_filter_params
    things_index_params.except(:page)
  end

  def things_search_hidden_params
    things_index_params.except(:q, :page)
  end

  def things_sort_link(label, column)
    active = @things_index.sort == column.to_s
    next_direction = if active
      @things_index.direction == "desc" ? "asc" : "desc"
    elsif Things::IndexQuery::ASC_DEFAULT_SORTS.include?(column.to_s)
      "asc"
    else
      "desc"
    end
    icon = if active
      tag.i(class: "bi bi-chevron-#{@things_index.direction == "asc" ? "up" : "down"} text-11")
    end

    link_to things_path(things_index_params(sort: column, direction: next_direction, page: 1)),
            class: class_names("scan-visits-sort text-reset text-decoration-none", "fw-medium" => active) do
      safe_join([ label, icon ].compact, " ")
    end
  end

  def things_filter_toggle(label, key)
    key = key.to_sym
    current = @things_index.filters[key]
    next_value = THINGS_FILTER_CYCLE[current]

    filters = @things_index.filters.values.dup
    if next_value
      filters[key] = next_value
    else
      filters.delete(key)
    end

    link_to things_path(things_index_params(filter: filter_params_with_sources(filters))),
            class: class_names("filter-chip", active: current.present?),
            title: "#{label}: #{THINGS_FILTER_STATES[current]} — click for #{THINGS_FILTER_STATES[next_value]}" do
      safe_join([ things_filter_icon(current), tag.span(label, class: things_filter_label_class(current)) ].compact, " ")
    end
  end

  def things_integration_filter_chips
    safe_join(
      Integrations::Registry.filter_keys.map { |key| things_integration_filter_chip(key) },
      " "
    )
  end

  def things_integration_filter_chip(key)
    label = Integrations::Registry.label_for(key)
    active = @things_index.filters.integration_active?(key)
    sources = @things_index.filters.sources.dup

    if active
      sources.delete(key)
    else
      sources << key
    end

    filters = @things_index.filters.values.dup
    filters[:integration] = sources.uniq if sources.any?

    link_to things_path(things_index_params(filter: filter_params_with_sources(filters, sources: sources))),
            class: class_names("filter-chip", active: active),
            title: "#{label}: #{active ? 'included' : 'not included'} — click to #{active ? 'remove' : 'add'}" do
      label
    end
  end

  def things_clear_filters_path
    things_path(things_index_params(filter: {}))
  end

  def things_filter_icon(state)
    case state
    when "yes" then tag.i(class: "bi bi-check-lg text-11")
    when "no" then tag.i(class: "bi bi-slash-lg text-11")
    end
  end

  def things_filter_label_class(state)
    "text-decoration-line-through" if state == "no"
  end

  def things_manufacturer_cell(thing)
    things_manufacturer_link(thing) || tag.span("—", class: "text-secondary")
  end

  def things_manufacturer_link(thing)
    return if thing.manufacturer.blank?

    if (url = thing.safe_manufacturer_url)
      link_to thing.manufacturer, url, class: "text-13", target: "_blank", rel: "noopener"
    else
      thing.manufacturer
    end
  end

  def things_subtitle_line(thing)
    [ thing.manufacturer.presence, thing.model.presence ].compact.join(" · ")
  end

  def things_photo_source(photo, variant_name)
    url_for(photo.variant(variant_name))
  rescue StandardError
    url_for(photo)
  end

  def things_photo_dimensions(photo, max_width: 400)
    blob = photo.blob
    width = blob.metadata["width"].to_i
    height = blob.metadata["height"].to_i
    return {} if width.zero? || height.zero?

    if width > max_width
      ratio = max_width.to_f / width
      { width: max_width, height: (height * ratio).round }
    else
      { width: width, height: height }
    end
  end

  def things_card_meta_line(thing)
    parts = [ thing.manufacturer.presence, thing.model.presence, thing.integration_label ].compact
    parts.join(" · ")
  end

  def things_where_presenter(thing)
    link = thing.where_link
    Things::WherePresenter.new(link) if link
  end

  def things_column_visible?(column)
    @things_columns.include?(column.to_s)
  end

  def things_column_toggle_path(column)
    visible = things_column_visible?(column)
    optional = @things_columns & THINGS_OPTIONAL_COLUMNS
    optional = visible ? optional - [ column.to_s ] : (optional + [ column.to_s ]).uniq
    things_path(things_index_params(columns: optional))
  end

  def things_active_filter_pills
    pills = []

    things_index_filter_groups.each do |group|
      state = @things_index.filters[group[:key]]
      next if state.blank?

      pills << things_active_filter_pill(group[:label], group[:key], state)
    end

    Integrations::Registry.filter_keys.each do |key|
      next unless @things_index.filters.integration_active?(key)

      pills << things_active_integration_pill(key)
    end

    safe_join(pills, " ")
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

    if overrides.key?(:columns)
      optional = Array(overrides[:columns]).select { |col| THINGS_OPTIONAL_COLUMNS.include?(col.to_s) }
      params[:columns] = optional if optional.any? || overrides[:columns].is_a?(Array)
    elsif @things_columns.present?
      optional = @things_columns & THINGS_OPTIONAL_COLUMNS
      params[:columns] = optional if optional.any?
    end

    filter_params = if overrides.key?(:filter)
      build_filter_params(overrides[:filter])
    elsif @things_index.filters.active?
      @things_index.filters.to_params
    end
    params[:filter] = filter_params if filter_params.present?

    params
  end

  private

  def build_filter_params(raw_filter)
    hash = raw_filter.to_h.stringify_keys
    integration = Array(hash.delete("integration")).map(&:to_s).select(&:present?)
    params = hash.select { |_, value| value.present? }
    params["integration"] = integration if integration.any?
    params
  end

  def filter_params_with_sources(values, sources: nil)
    merged_sources = sources || @things_index.filters.sources
    result = values.stringify_keys.select { |_, value| value.present? }
    result["integration"] = merged_sources if merged_sources.any?
    result
  end

  def things_active_filter_pill(label, key, state)
    filters = @things_index.filters.values.dup
    filters.delete(key)
    remove_path = things_path(things_index_params(filter: filter_params_with_sources(filters)))
    icon = state == "no" ? tag.i(class: "bi bi-slash-lg text-11") : tag.i(class: "bi bi-check-lg text-11")
    label_span = tag.span(label, class: things_filter_label_class(state))

    link_to remove_path, class: "active-filter-pill", title: "Remove filter" do
      safe_join([ icon, label_span, tag.i(class: "bi bi-x-lg text-11") ], " ")
    end
  end

  def things_active_integration_pill(key)
    label = Integrations::Registry.label_for(key)
    sources = @things_index.filters.sources.dup
    sources.delete(key)
    filters = @things_index.filters.values.dup
    filters[:integration] = sources if sources.any?
    remove_path = things_path(things_index_params(filter: filter_params_with_sources(filters, sources: sources)))

    link_to remove_path, class: "active-filter-pill", title: "Remove filter" do
      safe_join([ label, tag.i(class: "bi bi-x-lg text-11") ], " ")
    end
  end
end
