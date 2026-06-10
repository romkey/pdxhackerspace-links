class SiteSetting < ApplicationRecord
  validates :cups_server, presence: true

  def self.instance
    first_or_create!(cups_server: default_cups_server)
  end

  def self.default_cups_server
    ENV["CUPS_SERVER"].presence || "localhost:631"
  end
end
