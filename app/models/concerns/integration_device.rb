module IntegrationDevice
  extend ActiveSupport::Concern

  # auto_link is false after someone unlinks the record from its thing.
  # Imports then leave it unlinked until it is linked by hand.
  included do
    scope :active, -> { where(archived_at: nil) }
    scope :archived, -> { where.not(archived_at: nil) }
    scope :unlinked, -> { where(thing_id: nil) }
  end

  def archived?
    archived_at.present?
  end
end
