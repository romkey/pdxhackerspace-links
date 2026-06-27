module ApplicationHelper
  def app_version
    Rails.application.config.app_version
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
end
