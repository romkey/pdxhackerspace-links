class Printer < ApplicationRecord
  PAGE_SIZES = {
    "label_strip_24mm" => {
      label: "24mm label strip",
      category: "Label",
      media: "Custom.24x0mm",
      description: "Continuous 24mm-wide label stock"
    },
    "label_4x6" => {
      label: '4×6" label',
      category: "Label",
      media: "4x6",
      description: "4×6 inch shipping and parcel labels"
    },
    "letter" => {
      label: "Letter",
      category: "Laser",
      media: "Letter",
      description: "US letter (8.5×11\") laser or inkjet"
    },
    "receipt_80mm" => {
      label: "80mm receipt",
      category: "Receipt",
      media: "Custom.80x0mm",
      description: "80mm-wide thermal receipt roll"
    }
  }.freeze

  validates :name, presence: true
  validates :cups_name, presence: true, uniqueness: true
  validates :page_size, presence: true, inclusion: { in: PAGE_SIZES.keys }

  scope :enabled, -> { where(enabled: true) }
  scope :ordered, -> { order(:name) }

  def page_size_label
    PAGE_SIZES.dig(page_size, :label) || page_size
  end

  def page_size_category
    PAGE_SIZES.dig(page_size, :category)
  end

  def cups_media
    PAGE_SIZES.dig(page_size, :media)
  end
end
