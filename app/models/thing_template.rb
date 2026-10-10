# A reusable starting point for new things of the same kind. Only fields that
# stay the same from one instance to the next are kept: no serial number,
# network details, identifiers, photos, Where link, or related things.
class ThingTemplate < ApplicationRecord
  FIELDS = %i[description notes owner manufacturer model manufacturer_url public_access].freeze
  LINK_TYPES = (ThingLink::STANDARD_TYPES.keys - %w[where]).freeze
  FIELD_LABELS = {
    manufacturer_url: "Manufacturer link",
    public_access: "Public"
  }.freeze

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :manufacturer_url, format: {
    with: %r{\Ahttps?://.+\z}i,
    allow_blank: true,
    message: "must be an http or https URL"
  }

  before_validation :normalize_name

  scope :ordered, -> { order(Arel.sql("lower(name)")) }

  # Saving under an existing template's name replaces that template.
  def self.from_thing(thing, name:)
    template = where("lower(name) = ?", name.to_s.strip.downcase).first_or_initialize
    template.name = name
    template.capture(thing)
    template
  end

  def capture(thing)
    self.thing_name = thing.name
    FIELDS.each { |field| self[field] = thing[field] }
    self.links = self.class.links_from(thing)
  end

  def build_thing
    thing = Thing.new(name: thing_name, **FIELDS.index_with { |field| self[field] })
    standard_links.each do |data|
      thing.link_for(data["link_type"]).assign_attributes(url: data["url"], note: data["note"])
    end
    custom_links.each_with_index do |data, index|
      thing.links.build(link_type: :custom, title: data["title"], url: data["url"], note: data["note"], position: index)
    end
    thing
  end

  # Fills the thing's blank fields and links from the template without saving.
  # Anything already set is left alone; custom links are matched by title.
  # Returns labels describing what was filled in.
  def apply_to(thing)
    filled = []

    FIELDS.each do |field|
      next if self[field].blank? || thing[field].present? || thing[field] == false

      thing[field] = self[field]
      filled << self.class.field_label(field)
    end

    standard_links.each do |data|
      link = thing.link_for(data["link_type"])
      filled << ThingLink::STANDARD_TYPES[data["link_type"]] if fill_link(link, data)
    end

    position = (thing.custom_links.map(&:position).compact.max || -1) + 1
    custom_links.each do |data|
      existing = thing.custom_links.find { |link| link.title.to_s.casecmp?(data["title"].to_s) }
      if existing
        filled << data["title"] if fill_link(existing, data)
      else
        thing.links.build(link_type: :custom, title: data["title"], url: data["url"], note: data["note"], position: position)
        position += 1
        filled << data["title"]
      end
    end

    filled
  end

  def standard_links
    Array(links).select { |data| LINK_TYPES.include?(data["link_type"]) }
  end

  def custom_links
    Array(links).select { |data| data["link_type"] == "custom" }
  end

  def self.field_label(field)
    FIELD_LABELS[field] || human_attribute_name(field)
  end

  def self.links_from(thing)
    standard = thing.standard_links.filter_map do |link|
      next unless LINK_TYPES.include?(link.link_type)
      next unless link.present_link? || link.note.present?

      { "link_type" => link.link_type, "url" => link.url.presence, "note" => link.note.presence }
    end
    custom = thing.custom_links.filter_map do |link|
      next if link.marked_for_destruction? || link.title.blank?

      { "link_type" => "custom", "title" => link.title, "url" => link.url.presence, "note" => link.note.presence }
    end

    standard + custom
  end

  private

  def fill_link(link, data)
    changed = false
    %w[url note].each do |attribute|
      next if data[attribute].blank? || link[attribute].present?

      link[attribute] = data[attribute]
      changed = true
    end
    changed
  end

  def normalize_name
    self.name = name.to_s.strip.presence
  end
end
