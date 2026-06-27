class Thing < ApplicationRecord
  has_many :links, class_name: "ThingLink", dependent: :destroy, inverse_of: :thing
  has_many_attached :photos

  accepts_nested_attributes_for :links, allow_destroy: true, reject_if: :reject_blank_link?

  validates :name, presence: true
  validates :ip_address, format: { with: /\A(?:\d{1,3}\.){3}\d{1,3}\z/, allow_blank: true,
                                   message: "must be a valid IPv4 address" }
  validate :acceptable_photos

  scope :search, lambda { |query|
    term = query.to_s.strip
    next all if term.blank?

    pattern = "%#{sanitize_sql_like(term)}%"
    left_joins(:links).where(
      "things.name ILIKE :q OR things.description ILIKE :q OR things.notes ILIKE :q OR things.owner ILIKE :q OR things.ip_address ILIKE :q OR thing_links.title ILIKE :q OR thing_links.url ILIKE :q",
      q: pattern
    ).distinct
  }

  after_initialize :build_standard_links, if: :new_record?
  before_save :assign_custom_link_positions
  after_save :purge_blank_links

  def standard_links
    ThingLink::STANDARD_TYPES.keys.map { |type| link_for(type) }
  end

  def custom_links
    links.select(&:link_custom?).sort_by { |link| [ link.position || 0, link.id || 0 ] }
  end

  def link_for(type)
    links.find { |link| link.link_type == type } || links.build(link_type: type)
  end

  def links_with_urls
    links.select(&:present_link?).sort_by { |link| [ link.standard? ? 0 : 1, link.position || 0, link.display_title ] }
  end

  def label_title_line
    [ name, owner.presence ].compact.join(" ")
  end

  def label_ip_line
    ip_address.presence
  end

  private

  def reject_blank_link?(attributes)
    attributes["url"].to_s.blank? && attributes["title"].to_s.blank?
  end

  def assign_custom_link_positions
    links.select(&:link_custom?).reject(&:marked_for_destruction?).each_with_index do |link, index|
      link.position = index
    end
  end

  def purge_blank_links
    links.where(url: [ nil, "" ]).destroy_all
  end

  def build_standard_links
    ThingLink::STANDARD_TYPES.each_key do |type|
      link_for(type)
    end
  end

  def acceptable_photos
    photos.each do |photo|
      next if photo.content_type.in?(%w[image/jpeg image/png image/gif image/webp])

      errors.add(:photos, "must be JPEG, PNG, GIF, or WebP")
    end
  end
end
