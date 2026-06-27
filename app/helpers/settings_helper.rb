module SettingsHelper
  def settings_frame(&block)
    render(layout: "settings/frame", &block)
  end

  def settings_nav_class(section)
    classes = [ "settings-nav-item" ]
    classes << "active" if settings_nav_active?(section)
    classes.join(" ")
  end

  def settings_nav_active?(section)
    case section
    when :site
      controller_path == "settings/site"
    when :scan_visits
      controller_path == "settings/scan_visits"
    when :printers
      controller_path == "settings/printers"
    else
      false
    end
  end

  def scan_visits_sort_link(label, column)
    active = @scan_stats.sort == column.to_s
    next_direction = if active
      @scan_stats.direction == "desc" ? "asc" : "desc"
    elsif column.to_s == "name"
      "asc"
    else
      "desc"
    end
    icon = if active
      tag.i(class: "bi bi-chevron-#{@scan_stats.direction == "asc" ? "up" : "down"} text-11")
    end

    link_to settings_scan_visits_path(sort: column, direction: next_direction),
            class: class_names("scan-visits-sort text-reset text-decoration-none", "fw-medium" => active) do
      safe_join([ label, icon ].compact, " ")
    end
  end
end
