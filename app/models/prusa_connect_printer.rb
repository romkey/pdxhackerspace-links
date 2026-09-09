class PrusaConnectPrinter < ApplicationRecord
  include IntegrationDevice

  MANUFACTURER = "Prusa Research".freeze
  MANUFACTURER_URL = "https://www.prusa3d.com/".freeze

  belongs_to :prusa_connect_account
  belongs_to :thing, optional: true

  validates :external_id, presence: true, uniqueness: { scope: :prusa_connect_account_id }

  scope :ordered, -> { order(:name, :external_id) }

  def integration_source
    "prusa_connect"
  end

  def display_name
    name.presence || printer_type_name.presence || printer_model.presence || "Printer #{external_id}"
  end

  def fallback_thing_name
    identifier = ieee_address.presence || serial_number.presence || external_id
    "Printer #{identifier}"
  end

  def state_label
    state.to_s.tr("_", " ").capitalize.presence
  end

  def desired_thing_attributes
    {
      "name" => name.presence,
      "ieee_address" => ieee_address.presence,
      "hostname" => hostname.presence,
      "model" => printer_type_name.presence || printer_model.presence,
      "serial_number" => serial_number.presence,
      "manufacturer" => MANUFACTURER,
      "manufacturer_url" => MANUFACTURER_URL
    }.compact
  end
end
