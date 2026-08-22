class Zigbee2mqttDevice < ApplicationRecord
  include IntegrationDevice

  TYPE_LABELS = {
    "Coordinator" => "Coordinator",
    "Router" => "Router",
    "EndDevice" => "End device",
    "GreenPower" => "Green power",
    "Unknown" => "Unknown"
  }.freeze

  belongs_to :zigbee2mqtt_bridge
  belongs_to :thing, optional: true

  validates :ieee_address, presence: true, uniqueness: { scope: :zigbee2mqtt_bridge_id }

  scope :ordered, -> { order(:friendly_name, :ieee_address) }

  def integration_source
    "zigbee2mqtt"
  end

  def device_type_label
    TYPE_LABELS.fetch(device_type.to_s, device_type.to_s.humanize.presence || "Device")
  end

  def display_name
    friendly_name.presence || model.presence || "#{device_type_label} #{ieee_address}"
  end

  def desired_thing_attributes
    {
      "name" => friendly_name.presence,
      "ieee_address" => ieee_address.presence,
      "manufacturer" => manufacturer.presence,
      "model" => model.presence,
      "manufacturer_url" => Zigbee2mqtt::ManufacturerUrl.for(model)
    }.compact
  end

  def fallback_thing_name
    identifier = ieee_address.presence || friendly_name.presence || "device"
    "#{device_type_label} #{identifier}"
  end
end
