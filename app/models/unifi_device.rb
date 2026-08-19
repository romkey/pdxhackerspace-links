class UnifiDevice < ApplicationRecord
  KIND_LABELS = {
    "gateway" => "Gateway",
    "switch" => "Switch",
    "access_point" => "Access point",
    "device" => "Device",
    "camera" => "Camera",
    "light" => "Light",
    "sensor" => "Sensor",
    "chime" => "Chime",
    "viewer" => "Viewer",
    "speaker" => "Speaker",
    "bridge" => "Bridge",
    "fob" => "Fob",
    "siren" => "Siren",
    "relay" => "Relay",
    "alarm_hub" => "Alarm hub",
    "nvr" => "NVR"
  }.freeze

  ONLINE_STATES = %w[ONLINE CONNECTED].freeze

  enum :source, { network: "network", protect: "protect" }, prefix: :source

  belongs_to :unifi_controller
  belongs_to :thing, optional: true

  validates :external_id, presence: true, uniqueness: { scope: %i[unifi_controller_id source] }
  validates :kind, presence: true

  scope :active, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }
  scope :unlinked, -> { where(thing_id: nil) }
  scope :ordered, -> { order(:source, :kind, :name) }

  def archived?
    archived_at.present?
  end

  def kind_label
    KIND_LABELS.fetch(kind, kind.to_s.humanize)
  end

  def source_label
    source_network? ? "Network" : "Protect"
  end

  def online?
    state.in?(ONLINE_STATES)
  end

  def state_label
    state.to_s.tr("_", " ").capitalize.presence
  end

  def display_name
    name.presence || model.presence || "#{kind_label} #{external_id}"
  end
end
