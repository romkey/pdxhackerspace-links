class ThingRelationship < ApplicationRecord
  belongs_to :thing
  belongs_to :related_thing, class_name: "Thing"

  attr_accessor :syncing_inverse

  validates :related_thing_id, uniqueness: { scope: :thing_id }
  validate :cannot_relate_to_self

  after_create :create_inverse, unless: :syncing_inverse
  after_update :sync_inverse, unless: :syncing_inverse
  after_destroy :destroy_inverse, unless: :syncing_inverse

  private

  def cannot_relate_to_self
    return unless thing_id.present? && related_thing_id.present?
    return unless thing_id == related_thing_id

    errors.add(:related_thing, "can't be the same thing")
  end

  def create_inverse
    inverse = self.class.find_or_initialize_by(thing_id: related_thing_id, related_thing_id: thing_id)
    return if inverse.persisted?

    inverse.syncing_inverse = true
    inverse.note = note
    inverse.save!
  end

  def sync_inverse
    inverse = self.class.find_by(thing_id: related_thing_id, related_thing_id: thing_id)
    return unless inverse
    return if inverse.note == note

    inverse.syncing_inverse = true
    inverse.update!(note: note)
  end

  def destroy_inverse
    inverse = self.class.find_by(thing_id: related_thing_id, related_thing_id: thing_id)
    return unless inverse

    inverse.syncing_inverse = true
    inverse.destroy!
  end
end
