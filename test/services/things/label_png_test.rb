require "test_helper"

class Things::LabelPngTest < ActiveSupport::TestCase
  test "generates png with expected dimensions" do
    printer = printers(:command_printer)
    label = Things::LabelPng.new(thing: things(:router), printer: printer)
    path = label.generate

    assert File.exist?(path)
    assert_operator File.size(path), :>, 100

    image = ChunkyPNG::Image.from_file(path)
    width_mm = (image.width / Things::LabelPng::DPI.to_f * 25.4).round(1)
    height_mm = (image.height / Things::LabelPng::DPI.to_f * 25.4).round(1)

    assert_equal label.page_width_mm.round(1), width_mm
    assert_equal label.page_height_mm.round(1), height_mm

    left_third_dark_pixels = (0...(image.width / 3)).sum do |x|
      (0...image.height).count { |y| ChunkyPNG::Color.r(image[x, y]) < 200 }
    end
    assert_operator left_third_dark_pixels, :>, 100, "expected QR code pixels on the left side of the PNG label"
  ensure
    label&.cleanup!
  end
end
