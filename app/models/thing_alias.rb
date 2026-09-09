# Retired identifiers from things that were merged into another thing, so labels
# and NFC tags printed before the merge still resolve.
class ThingAlias < ApplicationRecord
  belongs_to :thing

  validates :key, uniqueness: { allow_blank: true }, format: { with: Thing::KEY_REGEX, allow_blank: true }
  validates :slug, uniqueness: { allow_blank: true }
  validate :has_an_identifier
  validate :key_not_taken_by_a_thing
  validate :slug_not_taken_by_a_thing

  before_validation :normalize_identifiers

  def self.thing_for_key(value)
    find_by(key: value)&.thing
  end

  def self.thing_for_slug(value)
    find_by(slug: value)&.thing
  end

  private

  def normalize_identifiers
    self.key = key.to_s.strip.downcase.presence
    self.slug = slug.to_s.strip.downcase.presence
  end

  def has_an_identifier
    return if key.present? || slug.present?

    errors.add(:base, "needs a key or a slug")
  end

  def key_not_taken_by_a_thing
    return if key.blank?
    return unless Thing.exists?(key: key)

    errors.add(:key, "is already used by a thing")
  end

  def slug_not_taken_by_a_thing
    return if slug.blank?
    return unless Thing.exists?(slug: slug)

    errors.add(:slug, "is already used by a thing")
  end
end
