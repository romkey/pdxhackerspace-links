class AddLabelPrintSettingsToSiteSettings < ActiveRecord::Migration[8.1]
  def change
    change_table :site_settings, bulk: true do |t|
      t.decimal :label_print_left_margin_mm, precision: 5, scale: 2, default: 0, null: false
      t.decimal :label_print_right_margin_mm, precision: 5, scale: 2, default: 3, null: false
      t.decimal :cable_tag_gap_mm, precision: 5, scale: 2, default: 10, null: false
    end
  end
end
