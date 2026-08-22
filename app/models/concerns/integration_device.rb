module IntegrationDevice
  extend ActiveSupport::Concern

  included do
    scope :active, -> { where(archived_at: nil) }
    scope :archived, -> { where.not(archived_at: nil) }
    scope :unlinked, -> { where(thing_id: nil) }
  end

  def archived?
    archived_at.present?
  end
end
