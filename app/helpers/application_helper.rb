module ApplicationHelper
  def app_version
    Rails.application.config.app_version
  end

  def app_version_display
    Links::Version.display(app_version)
  end

  def github_repo_url
    Links::Repository.url
  end

  def github_version_url
    Links::Repository.release_url(app_version)
  end

  def bootstrap_class_for(flash_type)
    case flash_type.to_sym
    when :notice, :success then "success"
    when :alert, :error then "danger"
    else "secondary"
    end
  end

  def nfc_tag_payload(thing)
    Things::NfcTagPayload.call(thing)
  end

  def site_setting
    @site_setting ||= SiteSetting.instance
  end

  def relative_time(time)
    return if time.blank?

    time = time.in_time_zone
    now = Time.current
    title = time.to_fs(:long)

    text = if time.to_date == now.to_date
      time.strftime("%-I:%M %p")
    elsif time.to_date == (now.to_date - 1)
      "Yesterday"
    elsif time >= 7.days.ago
      days = (now.to_date - time.to_date).to_i
      days = 1 if days < 1
      "#{days} #{'day'.pluralize(days)} ago"
    elsif time.year == now.year
      time.strftime("%b %-d")
    else
      time.strftime("%b %-d, %Y")
    end

    tag.time(text, datetime: time.iso8601, title: title)
  end
end
