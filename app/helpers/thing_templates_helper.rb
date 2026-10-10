module ThingTemplatesHelper
  THING_TEMPLATE_FIELD_LABELS = {
    manufacturer_url: "Manufacturer link",
    public_access: "Public"
  }.freeze

  # Label/value pairs for the fields a template fills in, skipping blanks.
  def thing_template_content_rows(template)
    rows = [ [ "Name", template.thing_name ] ]
    ThingTemplate::FIELDS.each do |field|
      value = template[field]
      value = value ? "Yes" : nil if field == :public_access
      rows << [ THING_TEMPLATE_FIELD_LABELS[field] || ThingTemplate.human_attribute_name(field), value ]
    end
    template.standard_links.each do |data|
      rows << [ ThingLink::STANDARD_TYPES[data["link_type"]], thing_template_link_summary(data) ]
    end
    template.custom_links.each do |data|
      rows << [ data["title"], thing_template_link_summary(data) ]
    end

    rows.select { |_label, value| value.present? }
  end

  def thing_template_link_summary(data)
    [ data["url"], data["note"] ].compact_blank.join(" · ")
  end
end
