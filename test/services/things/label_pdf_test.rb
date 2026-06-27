require "test_helper"
require "open3"
require "chunky_png"

class Things::LabelPdfTest < ActiveSupport::TestCase
  test "generates a pdf file for brother labels" do
    label_pdf = Things::LabelPdf.new(thing: things(:keyboard), printer: printers(:brother_printer))
    path = label_pdf.generate

    assert File.exist?(path)
    assert File.read(path, 4).start_with?("%PDF")
    assert label_pdf.landscape?
    assert_in_delta 62, label_pdf.page_height_mm, 0.1
    assert_operator label_pdf.page_width_mm, :>, label_pdf.page_height_mm
  ensure
    label_pdf&.cleanup!
  end

  test "generates a pdf file for letter printers with avery templates" do
    label_pdf = Things::LabelPdf.new(thing: things(:keyboard), printer: printers(:office_laser))
    path = label_pdf.generate

    assert File.exist?(path)
    assert File.read(path, 4).start_with?("%PDF")
    assert_not label_pdf.landscape?
  ensure
    label_pdf&.cleanup!
  end

  test "generates a pdf file for 24mm strip labels" do
    label_pdf = Things::LabelPdf.new(thing: things(:router), printer: printers(:label_printer))
    path = label_pdf.generate

    assert File.exist?(path)
    assert File.read(path, 4).start_with?("%PDF")
    assert label_pdf.landscape?
    assert_in_delta 24, label_pdf.page_height_mm, 0.1
  ensure
    label_pdf&.cleanup!
  end

  test "24mm strip label is landscape with feed margin along the width" do
    pdf = Things::LabelPdf.new(thing: things(:router), printer: printers(:label_printer))
    margin = Things::LabelPdf::STRIP_24MM_MARGIN_MM
    qr = Things::LabelPdf::STRIP_24MM_ROLL_WIDTH_MM - (2 * margin)
    expected_width = (margin + qr + Things::LabelPdf::STRIP_24MM_TEXT_GAP_MM +
                     Things::LabelPdf::STRIP_24MM_TEXT_MIN_WIDTH_MM + margin +
                     Things::LabelPdf::STRIP_24MM_FEED_MARGIN_MM).round

    assert_equal expected_width, pdf.page_width_mm
    assert_equal expected_width, pdf.cups_media[/Custom\.24x(\d+)mm/, 1].to_i
    assert_in_delta 24, pdf.page_height_mm, 0.1
  end

  test "landscape label embeds qr image" do
    label_pdf = Things::LabelPdf.new(thing: things(:router), printer: printers(:label_printer))
    path = label_pdf.generate
    content = File.binread(path)

    assert_includes content.force_encoding(Encoding::BINARY), "/Subtype /Image"
    assert_qr_visible_in_label_pdf(path)
  ensure
    label_pdf&.cleanup!
  end

  test "brother landscape label embeds visible qr image" do
    label_pdf = Things::LabelPdf.new(thing: things(:router), printer: printers(:brother_printer))
    path = label_pdf.generate

    assert_qr_visible_in_label_pdf(path)
  ensure
    label_pdf&.cleanup!
  end

  test "avery letter label embeds visible qr image" do
    label_pdf = Things::LabelPdf.new(thing: things(:keyboard), printer: printers(:office_laser))
    path = label_pdf.generate

    assert_qr_visible_in_label_pdf(path, region: :any)
  ensure
    label_pdf&.cleanup!
  end

  test "pdf_data returns bytes and cleans up temp file" do
    label_pdf = Things::LabelPdf.new(thing: things(:router), printer: printers(:label_printer))

    data = label_pdf.pdf_data
    assert data.start_with?("%PDF")
    assert_not label_pdf.instance_variable_get(:@generated_path)
  end

  test "24mm strip label grows when ar marker is attached" do
    thing = attach_ar_anchor(things(:router))
    pdf = Things::LabelPdf.new(thing: thing, printer: printers(:label_printer))
    margin = Things::LabelPdf::STRIP_24MM_MARGIN_MM
    qr = Things::LabelPdf::STRIP_24MM_ROLL_WIDTH_MM - (2 * margin)
    base_width = (margin + qr + Things::LabelPdf::STRIP_24MM_TEXT_GAP_MM +
                  Things::LabelPdf::STRIP_24MM_TEXT_MIN_WIDTH_MM + margin +
                  Things::LabelPdf::STRIP_24MM_FEED_MARGIN_MM).round
    marker_width = Things::LabelPdf::AR_MARKER_GAP_MM + Things::LabelPdf::STRIP_24MM_ROLL_WIDTH_MM

    assert_equal base_width + marker_width, pdf.page_width_mm
  ensure
    pdf&.cleanup! if pdf&.instance_variable_get(:@generated_path)
  end

  test "landscape label embeds qr and ar marker images" do
    thing = attach_ar_anchor(things(:router))
    label_pdf = Things::LabelPdf.new(thing: thing, printer: printers(:label_printer))
    path = label_pdf.generate
    content = File.binread(path)
    image_count = content.scan("/Subtype /Image").size

    assert_operator image_count, :>=, 2, "expected QR code and AR marker images in label PDF"
  ensure
    label_pdf&.cleanup!
  end

  test "landscape label skips missing ar marker file without error" do
    thing = attach_ar_anchor(things(:router))
    blob = thing.ar_anchor.blob
    ActiveStorage::Blob.service.delete(blob.key)

    label_pdf = Things::LabelPdf.new(thing: thing, printer: printers(:label_printer))

    assert_nothing_raised { label_pdf.generate }
    assert_in_delta label_pdf.page_width_mm, Things::LabelPdf.new(thing: things(:router), printer: printers(:label_printer)).page_width_mm, 0.1
  ensure
    label_pdf&.cleanup!
  end

  private

  def assert_qr_visible_in_label_pdf(path, region: :left)
    png_path = rasterize_label_pdf(path)
    image = ChunkyPNG::Image.from_file(png_path)
    x_range = case region
    when :left
      0...(image.width / 3)
    when :center
      (image.width / 3)...(2 * image.width / 3)
    else
      0...image.width
    end
    dark_pixels = dark_pixel_count(image, x_range: x_range)

    assert_operator dark_pixels, :>, 100, "expected QR code pixels in the #{region} region of the label"
  ensure
    File.delete(png_path) if png_path && File.exist?(png_path)
  end

  def rasterize_label_pdf(path)
    base = Tempfile.new([ "label-test", "" ]).path
    _stdout, stderr, status = Open3.capture3(
      "pdftoppm", "-png", "-singlefile", "-rx", "150", "-ry", "150", path, base
    )
    raise "pdftoppm failed: #{stderr}" unless status.success?

    "#{base}.png"
  end

  def dark_pixel_count(image, x_range:, y_range: nil)
    y_range ||= 0...image.height
    count = 0

    x_range.each do |x|
      y_range.each do |y|
        count += 1 if ChunkyPNG::Color.r(image[x, y]) < 200
      end
    end

    count
  end
end
