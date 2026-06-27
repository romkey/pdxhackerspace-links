class Printer < ApplicationRecord
  CUPS_SERVER_FORMAT = /\A[^:\s]+(?::\d+)?\z/
  PRINT_COMMAND_FILENAME = "FILENAME"

  enum :printer_type, { cups: "cups", command: "command" }, default: :cups

  PAGE_SIZE_GROUPS = {
    "brother_label" => "Brother label",
    "label" => "Label",
    "letter" => "Letter",
    "receipt" => "Receipt"
  }.freeze

  PAGE_SIZES = {
    "label_brother_12mm" => {
      label: "12mm continuous",
      group: "brother_label",
      media: "Custom.12x0mm",
      description: "Brother DK continuous roll, 12mm wide (QL series)"
    },
    "label_brother_29mm" => {
      label: "29mm continuous",
      group: "brother_label",
      media: "Custom.29x0mm",
      description: "Brother DK continuous roll, 29mm wide"
    },
    "label_brother_38mm" => {
      label: "38mm continuous",
      group: "brother_label",
      media: "Custom.38x0mm",
      description: "Brother DK continuous roll, 38mm wide"
    },
    "label_brother_62mm" => {
      label: "62mm continuous",
      group: "brother_label",
      media: "Custom.62x0mm",
      description: "Brother DK continuous roll, 62mm wide (QL-700, QL-800, QL-820NWB)"
    },
    "label_brother_62x100" => {
      label: "62×100mm die-cut",
      group: "brother_label",
      media: "DC62x100",
      description: "Brother DK die-cut labels, 62mm × 100mm"
    },
    "label_brother_102mm" => {
      label: "102mm continuous",
      group: "brother_label",
      media: "Custom.102x0mm",
      description: "Brother DK continuous roll, 102mm wide (QL-1100/1110NWB)"
    },
    "label_strip_24mm" => {
      label: "24mm label strip",
      group: "label",
      media: "Custom.24x0mm",
      description: "Continuous 24mm-wide label stock"
    },
    "label_4x6" => {
      label: '4×6" label',
      group: "label",
      media: "4x6",
      description: "4×6 inch shipping and parcel labels"
    },
    "letter" => {
      label: "Letter",
      group: "letter",
      media: "Letter",
      description: "US letter (8.5×11\") laser or inkjet, with optional Avery templates"
    },
    "receipt_80mm" => {
      label: "80mm receipt",
      group: "receipt",
      media: "Custom.80x0mm",
      description: "80mm-wide thermal receipt roll"
    }
  }.freeze

  AVERY_TEMPLATES = {
    "avery_5160" => {
      label: "Avery 5160",
      description: "Address labels, 1\" × 2⅝\", 30 per sheet",
      columns: 3,
      rows: 10,
      label_width_in: 2.625,
      label_height_in: 1.0
    },
    "avery_5161" => {
      label: "Avery 5161",
      description: "Address labels, 1\" × 4\", 20 per sheet",
      columns: 2,
      rows: 10,
      label_width_in: 4.0,
      label_height_in: 1.0
    },
    "avery_5163" => {
      label: "Avery 5163",
      description: "Shipping labels, 2\" × 4\", 10 per sheet",
      columns: 2,
      rows: 5,
      label_width_in: 4.0,
      label_height_in: 2.0
    },
    "avery_5164" => {
      label: "Avery 5164",
      description: "Shipping labels, 3⅓\" × 4\", 6 per sheet",
      columns: 2,
      rows: 3,
      label_width_in: 4.0,
      label_height_in: 3.333
    },
    "avery_5260" => {
      label: "Avery 5260",
      description: "Address labels, 1\" × 2⅝\", 30 per sheet (same layout as 5160)",
      columns: 3,
      rows: 10,
      label_width_in: 2.625,
      label_height_in: 1.0
    },
    "avery_5520" => {
      label: "Avery 5520",
      description: "Business cards, 2\" × 3½\", 10 per sheet",
      columns: 2,
      rows: 5,
      label_width_in: 3.5,
      label_height_in: 2.0
    },
    "avery_8460" => {
      label: "Avery 8460",
      description: "CD/DVD labels, 4⅔\" diameter, 2 per sheet",
      columns: 2,
      rows: 1,
      label_width_in: 4.625,
      label_height_in: 4.625
    }
  }.freeze

  validates :name, presence: true
  validates :cups_name, presence: true, uniqueness: { scope: :cups_server }, if: :cups?
  validates :cups_server, presence: true, format: { with: CUPS_SERVER_FORMAT }, if: :cups?
  validates :page_size, presence: true, inclusion: { in: PAGE_SIZES.keys }, if: :cups?
  validates :avery_template, inclusion: { in: AVERY_TEMPLATES.keys }, allow_blank: true
  validates :label_height_mm,
            presence: true,
            numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 200 },
            if: :command?
  validates :print_command, presence: true, if: :command?
  validate :avery_template_requires_letter_page_size, if: :cups?
  validate :print_command_includes_filename, if: :command?

  normalizes :cups_server, with: ->(value) { value.to_s.strip }

  scope :enabled, -> { where(enabled: true) }
  scope :ordered, -> { order(:name) }

  def page_size_label
    PAGE_SIZES.dig(page_size, :label) || page_size
  end

  def page_size_group
    PAGE_SIZES.dig(page_size, :group)
  end

  def page_size_group_label
    PAGE_SIZE_GROUPS[page_size_group] || page_size_group
  end

  def cups_media
    PAGE_SIZES.dig(page_size, :media)
  end

  def supports_avery_templates?
    page_size == "letter"
  end

  def avery_template_label
    AVERY_TEMPLATES.dig(avery_template, :label)
  end

  def avery_template_config
    AVERY_TEMPLATES[avery_template] if avery_template.present?
  end

  def cups_client
    Cups::Client.new(server: cups_server)
  end

  def continuous_roll?
    Cups::Client.continuous_media?(cups_media)
  end

  def roll_width_mm
    return label_height_mm if command?
    return unless (match = Cups::Client::CONTINUOUS_MEDIA_FORMAT.match(cups_media))

    match[1].to_i
  end

  def printer_type_label
    command? ? "Command" : "CUPS"
  end

  def landscape_label?
    return true if command?

    continuous_roll? && page_size != "receipt_80mm"
  end

  def cuts_after_print?
    continuous_roll?
  end

  def precut_before?
    command? && precut_before
  end

  def self.default_cups_server
    SiteSetting.instance.cups_server
  end

  private

  def avery_template_requires_letter_page_size
    return if avery_template.blank?
    return if supports_avery_templates?

    errors.add(:avery_template, "is only supported for letter page size")
  end

  def print_command_includes_filename
    return if print_command.blank?
    return if print_command.include?(PRINT_COMMAND_FILENAME)

    errors.add(:print_command, "must include #{PRINT_COMMAND_FILENAME}")
  end
end
