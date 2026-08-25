class SiteSetting < ApplicationRecord
  DEFAULT_LABEL_PRINT_LEFT_MARGIN_MM = 0
  DEFAULT_LABEL_PRINT_RIGHT_MARGIN_MM = 3
  DEFAULT_CABLE_TAG_GAP_MM = 10
  MAX_LABEL_MARGIN_MM = 50

  validates :cups_server, presence: true
  validates :label_print_left_margin_mm,
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: MAX_LABEL_MARGIN_MM }
  validates :label_print_right_margin_mm,
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: MAX_LABEL_MARGIN_MM }
  validates :cable_tag_gap_mm,
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: MAX_LABEL_MARGIN_MM }
  validates :matomo_url, format: {
    with: %r{\Ahttps?://.+\z}i,
    allow_blank: true,
    message: "must be an http or https URL"
  }
  validates :matomo_site_id, format: {
    with: /\A\d+\z/,
    allow_blank: true,
    message: "must be a number"
  }
  validate :matomo_fields_paired

  def self.instance
    first_or_create!(cups_server: default_cups_server)
  end

  def self.default_cups_server
    ENV["CUPS_SERVER"].presence || "localhost:631"
  end

  def matomo_enabled?
    matomo_url.present? && matomo_site_id.present?
  end

  def matomo_tracker_base
    return unless matomo_enabled?

    base = matomo_url.to_s.strip
    base += "/" unless base.end_with?("/")
    base
  end

  private

  def matomo_fields_paired
    return if matomo_url.blank? && matomo_site_id.blank?
    return if matomo_url.present? && matomo_site_id.present?

    errors.add(:base, "Matomo URL and site ID must both be set or both be blank")
  end
end
