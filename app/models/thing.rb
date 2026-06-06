class Thing < ApplicationRecord
  has_many :links, class_name: "ThingLink", dependent: :destroy, inverse_of: :thing
  has_many_attached :photos

  accepts_nested_attributes_for :links, allow_destroy: true, reject_if: :reject_blank_link?

  validates :name, presence: true
  validate :acceptable_photos

  after_initialize :build_standard_links, if: :new_record?
  after_save :purge_blank_links

  def standard_links
    ThingLink::STANDARD_TYPES.keys.map { |type| link_for(type) }
  end

  def custom_links
    links.select(&:link_custom?).sort_by { |link| [link.position || 0, link.id || 0] }
  end

  def link_for(type)
    links.find { |link| link.link_type == type } || links.build(link_type: type)
  end

  def links_with_urls
    links.select(&:present_link?).sort_by { |link| [link.standard? ? 0 : 1, link.position || 0, link.display_title] }
  end

  private

  def reject_blank_link?(attributes)
    attributes["url"].to_s.blank? && attributes["title"].to_s.blank?
  end

  def purge_blank_links
    links.where(url: [nil, ""]).destroy_all
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
