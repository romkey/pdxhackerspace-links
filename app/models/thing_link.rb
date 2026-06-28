class ThingLink < ApplicationRecord
  STANDARD_TYPES = {
    "asset" => "Asset",
    "wiki" => "Wiki",
    "slack" => "Slack",
    "where" => "Where",
    "ar" => "AR"
  }.freeze

  belongs_to :thing

  enum :link_type, {
    asset: "asset",
    wiki: "wiki",
    slack: "slack",
    where: "where",
    ar: "ar",
    custom: "custom"
  }, prefix: :link

  validates :title, presence: true, if: :link_custom?
  validates :url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), allow_blank: true }
  validates :link_type, uniqueness: { scope: :thing_id }, unless: :link_custom?
  validate :custom_link_has_url

  scope :standard, -> { where(link_type: STANDARD_TYPES.keys) }
  scope :custom, -> { where(link_type: "custom") }
  scope :with_url, -> { where.not(url: [ nil, "" ]) }
  scope :ordered, -> { order(Arel.sql("CASE WHEN link_type = 'custom' THEN 1 ELSE 0 END"), :position, :link_type) }

  before_validation :clear_blank_custom_links

  def display_title
    link_custom? ? title : STANDARD_TYPES[link_type]
  end

  def standard?
    STANDARD_TYPES.key?(link_type)
  end

  def present_link?
    url.present?
  end

  def standard_note?
    standard? && note.present?
  end

  def safe_href
    return if url.blank?

    uri = URI.parse(url.strip)
    url if uri.is_a?(URI::HTTP) && uri.host.present?
  rescue URI::InvalidURIError
    nil
  end

  private

  def clear_blank_custom_links
    return unless link_custom?

    mark_for_destruction if title.blank? && url.blank?
  end

  def custom_link_has_url
    return unless link_custom?
    return if marked_for_destruction?
    return if title.blank? && url.blank?

    errors.add(:url, "can't be blank") if url.blank?
  end
end
