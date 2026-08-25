class Zigbee2mqttBridge < ApplicationRecord
  include IntegrationSource

  encrypts :mqtt_password

  has_many :zigbee2mqtt_devices, dependent: :destroy
  has_many :things, -> { distinct }, through: :zigbee2mqtt_devices

  validates :name, presence: true, uniqueness: true
  validates :mqtt_host, presence: true
  validates :mqtt_port, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 65_535 }
  validates :base_topic, presence: true
  validates :last_seen_limit_days, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  normalizes :name, with: ->(value) { value.to_s.strip }
  normalizes :mqtt_host, with: ->(value) { value.to_s.strip.downcase }
  normalizes :base_topic, with: ->(value) { value.to_s.strip.presence || "zigbee2mqtt" }

  scope :enabled, -> { where(enabled: true) }
  scope :ordered, -> { order(:name) }

  def client(transport: nil)
    Zigbee2mqtt::Client.for(self, transport: transport)
  end

  def device_count
    zigbee2mqtt_devices.active.count
  end

  def connection_label
    "#{mqtt_host}:#{mqtt_port}/#{base_topic}"
  end
end
