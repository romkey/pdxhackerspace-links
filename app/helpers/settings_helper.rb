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
    when :printers
      controller_path == "settings/printers"
    else
      false
    end
  end
end
