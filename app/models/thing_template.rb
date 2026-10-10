# A reusable starting point for new things of the same kind. Only fields that
# stay the same from one instance to the next are kept: no serial number,
# network details, identifiers, photos, Where link, or related things.
class ThingTemplate < ApplicationRecord
  FIELDS = %i[description notes owner manufacturer model manufacturer_url public_access].freeze
  LINK_TYPES = (ThingLink::STANDARD_TYPES.keys - %w[where]).freeze

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

  def standard_links
    Array(links).select { |data| LINK_TYPES.include?(data["link_type"]) }
  end

  def custom_links
    Array(links).select { |data| data["link_type"] == "custom" }
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

  def normalize_name
    self.name = name.to_s.strip.presence
  end
end
