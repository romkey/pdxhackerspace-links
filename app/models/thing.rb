class Thing < ApplicationRecord
  IPV4_REGEX = /\A(?:\d{1,3}\.){3}\d{1,3}\z/
  HOSTNAME_REGEX = /\A(?=.{1,253}\z)(?!-)[a-zA-Z0-9-]{1,63}(?<!-)(?:\.(?!-)[a-zA-Z0-9-]{1,63}(?<!-))*\z/
  BLE_BEACON_UUID_REGEX = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/
  SLUG_REGEX = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/
  RESERVED_SLUGS = %w[by_beacon new edit].freeze

  has_many :links, class_name: "ThingLink", dependent: :destroy, inverse_of: :thing
  has_many_attached :photos
  has_one_attached :ar_anchor

  accepts_nested_attributes_for :links, allow_destroy: true, reject_if: :reject_blank_link?

  validates :name, presence: true
  validates :slug, uniqueness: { allow_blank: true }
  validates :ble_beacon_uuid, uniqueness: { allow_blank: true }
  validate :ip_address_or_hostname
  validate :ble_beacon_uuid_format
  validate :slug_format

  before_validation :normalize_slug
  before_validation :normalize_ble_beacon_uuid
  validate :acceptable_photos
  validate :acceptable_ar_anchor

  scope :publicly_accessible, -> { where(public_access: true) }

  scope :search, lambda { |query|
    term = query.to_s.strip
    next all if term.blank?

    pattern = "%#{sanitize_sql_like(term)}%"
    left_joins(:links).where(
      "things.name ILIKE :q OR things.slug ILIKE :q OR things.description ILIKE :q OR things.notes ILIKE :q OR things.ar_anchor_note ILIKE :q OR things.owner ILIKE :q OR things.ip_address ILIKE :q OR things.ble_beacon_uuid ILIKE :q OR thing_links.title ILIKE :q OR thing_links.url ILIKE :q OR thing_links.note ILIKE :q",
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

  def links_for_display
    links.select { |link| link.present_link? || link.standard_note? }.sort_by do |link|
      [ link.standard? ? 0 : 1, link.position || 0, link.display_title ]
    end
  end

  def label_title_line
    [ name, owner.presence ].compact.join(" ")
  end

  def label_ip_line
    ip_address.presence
  end

  def scan_total_count
    qr_scan_count + nfc_scan_count
  end

  def to_param
    slug.presence || id.to_s
  end

  def self.find_by_slug_or_id!(param)
    find_by(slug: param) || find(param)
  end

  private

  def normalize_slug
    self.slug = slug.to_s.strip.downcase.presence
  end

  def slug_format
    value = slug.to_s
    return if value.blank?
    return if value.match?(SLUG_REGEX) && !RESERVED_SLUGS.include?(value)

    if RESERVED_SLUGS.include?(value)
      errors.add(:slug, "is reserved")
    else
      errors.add(:slug, "must contain only lowercase letters, numbers, and hyphens")
    end
  end

  def normalize_ble_beacon_uuid
    self.ble_beacon_uuid = ble_beacon_uuid.to_s.strip.downcase.presence
  end

  def ble_beacon_uuid_format
    value = ble_beacon_uuid.to_s
    return if value.blank?
    return if value.match?(BLE_BEACON_UUID_REGEX)

    errors.add(:ble_beacon_uuid, "must be a valid UUID")
  end

  def ip_address_or_hostname
    value = ip_address.to_s.strip
    return if value.blank?
    return if value.match?(IPV4_REGEX)
    return if value.match?(HOSTNAME_REGEX)

    errors.add(:ip_address, "must be a valid IPv4 address or hostname")
  end

  def reject_blank_link?(attributes)
    attributes["note"].blank? && attributes["url"].blank? && attributes["title"].blank?
  end

  def assign_custom_link_positions
    links.select(&:link_custom?).reject(&:marked_for_destruction?).each_with_index do |link, index|
      link.position = index
    end
  end

  def purge_blank_links
    links.find_each do |link|
      next if link.url.present?
      next if link.note.present?
      next if link.link_custom? && link.title.present?

      link.destroy
    end
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

  def acceptable_ar_anchor
    return unless ar_anchor.attached?

    unless ar_anchor.content_type.in?(%w[image/jpeg image/png image/gif image/webp])
      errors.add(:ar_anchor, "must be JPEG, PNG, GIF, or WebP")
    end
  end
end
