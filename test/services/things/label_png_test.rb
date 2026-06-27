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
  ensure
    label&.cleanup!
  end
end
