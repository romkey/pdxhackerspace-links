module JournalEntriesHelper
  JOURNAL_LIMIT = 50

  JOURNAL_EVENT_LABELS = {
    "created" => "Created",
    "updated" => "Updated",
    "refreshed" => "Refreshed",
    "merged" => "Merged",
    "recorded" => "Recorded"
  }.freeze

  JOURNAL_FIELD_LABELS = {
    "ip_address" => "IP address",
    "ieee_address" => "IEEE address",
    "manufacturer_url" => "Manufacturer link",
    "ble_beacon_uuid" => "BLE beacon UUID",
    "ar_anchor_note" => "AR marker note",
    "public_access" => "Public"
  }.freeze

  JOURNAL_VALUE_LENGTH = 80

  def journal_event_label(entry)
    JOURNAL_EVENT_LABELS[entry.event] || entry.event.humanize
  end

  def journal_actor(entry)
    entry.user&.name || "System"
  end

  def journal_field_label(entry, field)
    return "Template name" if field == "name" && entry.journalable_type == "ThingTemplate"

    JOURNAL_FIELD_LABELS[field] || field.humanize
  end

  def journal_value(value)
    case value
    when true then "Yes"
    when false then "No"
    when nil then "—"
    else truncate(value.to_s.squish, length: JOURNAL_VALUE_LENGTH)
    end
  end

  # One line per changed field or link. Entries that start a journal list
  # values as set rather than as changes from nothing.
  def journal_change_lines(entry)
    initial = entry.event.in?(%w[created recorded])
    lines = entry.field_changes.map do |field, (old, new)|
      label = journal_field_label(entry, field)
      initial ? "#{label}: #{journal_value(new)}" : "#{label}: #{journal_value(old)} → #{journal_value(new)}"
    end

    entry.links_added.each do |link|
      lines << "Added #{link['label']} link: #{journal_link_summary(link)}"
    end
    entry.links_modified.each do |link|
      link["changes"].each do |attribute, (old, new)|
        lines << if attribute == "label"
          "Renamed link: #{journal_value(old)} → #{journal_value(new)}"
        else
          "#{link['label']} link #{attribute == 'url' ? 'URL' : attribute}: #{journal_value(old)} → #{journal_value(new)}"
        end
      end
    end
    entry.links_removed.each do |link|
      lines << "Removed #{link['label']} link: #{journal_link_summary(link)}"
    end

    lines
  end

  def journal_link_summary(link)
    [ link["url"], link["note"] ].compact_blank.map { |value| journal_value(value) }.join(" · ").presence || "—"
  end

  def journal_things(entry)
    safe_join(entry.things.map { |thing| link_to(thing["name"], thing_path(thing["id"])) }, ", ")
  end
end
