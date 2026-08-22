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
    qr = Things::LabelPdf::STRIP_24MM_ROLL_WIDTH_MM
    text_width = pdf.send(:strip_text_width_mm)
    expected_width = (pdf.left_margin_mm + qr + Things::LabelPdf::STRIP_24MM_TEXT_GAP_MM + text_width + pdf.right_margin_mm).round

    assert_in_delta expected_width, pdf.page_width_mm, 0.5
    assert_equal pdf.page_width_mm.round, pdf.cups_media[/Custom\.24x(\d+)mm/, 1].to_i
    assert_in_delta 24, pdf.page_height_mm, 0.1
  end

  test "24mm strip qr code uses full strip height" do
    label_pdf = Things::LabelPdf.new(thing: things(:router), printer: printers(:label_printer))
    path = label_pdf.generate
    png_path = rasterize_label_pdf(path)
    image = ChunkyPNG::Image.from_file(png_path)
    qr_top, qr_bottom = qr_vertical_extent(image, x_range: 0...(image.width / 3))

    assert_operator qr_bottom - qr_top, :>=, (image.height * 0.9).round
  ensure
    label_pdf&.cleanup!
    File.delete(png_path) if png_path && File.exist?(png_path)
  end

  test "command printer qr code uses full strip height" do
    label_pdf = Things::LabelPdf.new(thing: things(:router), printer: printers(:command_printer))
    path = label_pdf.generate
    png_path = rasterize_label_pdf(path)
    image = ChunkyPNG::Image.from_file(png_path)
    qr_top, qr_bottom = qr_vertical_extent(image, x_range: 0...(image.width / 3))

    assert_in_delta 24, label_pdf.page_height_mm, 0.1
    assert_operator qr_bottom - qr_top, :>=, (image.height * 0.9).round
  ensure
    label_pdf&.cleanup!
    File.delete(png_path) if png_path && File.exist?(png_path)
  end

  test "brother roll qr code uses full roll width height" do
    label_pdf = Things::LabelPdf.new(thing: things(:router), printer: printers(:brother_printer))
    path = label_pdf.generate
    png_path = rasterize_label_pdf(path)
    image = ChunkyPNG::Image.from_file(png_path)
    qr_top, qr_bottom = qr_vertical_extent(image, x_range: 0...(image.width / 3))

    assert_in_delta 62, label_pdf.page_height_mm, 0.1
    assert_operator qr_bottom - qr_top, :>=, (image.height * 0.9).round
  ensure
    label_pdf&.cleanup!
    File.delete(png_path) if png_path && File.exist?(png_path)
  end

  test "qr code encodes SHORT_URL and thing key even when slug is set" do
    with_short_url_host("http://l.ctrlh") do
      thing = things(:keyboard)
      url = Things::LabelPdf.new(thing: thing, printer: printers(:label_printer)).send(:thing_url)

      assert_equal "http://l.ctrlh/#{thing.key}?q", url
      assert_not_includes url, "/things/"
      assert_not_includes url, thing.slug
    end
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

  test "generates a pdf file for 24mm cable tag labels" do
    label_pdf = Things::LabelPdf.new(
      thing: things(:router),
      printer: printers(:label_printer),
      layout: :cable_tag
    )
    path = label_pdf.generate

    assert File.exist?(path)
    assert File.read(path, 4).start_with?("%PDF")
    assert label_pdf.landscape?
    assert_in_delta 24, label_pdf.page_height_mm, 0.1
    assert label_pdf.cable_tag?
  ensure
    label_pdf&.cleanup!
  end

  test "cable tag label width includes two segments, wrap gap, and feed margin" do
    pdf = Things::LabelPdf.new(
      thing: things(:router),
      printer: printers(:label_printer),
      layout: :cable_tag
    )
    segment = pdf.send(:cable_tag_segment_width_mm)
    expected_width = (pdf.left_margin_mm + segment + pdf.cable_tag_gap_mm + segment + pdf.right_margin_mm).round

    assert_equal expected_width, pdf.page_width_mm
    assert_equal expected_width, pdf.cups_media[/Custom\.24x(\d+)mm/, 1].to_i
  end

  test "cable tag label embeds two visible qr codes for wrap-around sides" do
    label_pdf = Things::LabelPdf.new(
      thing: things(:router),
      printer: printers(:label_printer),
      layout: :cable_tag
    )
    path = label_pdf.generate
    png_path = rasterize_label_pdf(path)
    image = ChunkyPNG::Image.from_file(png_path)
    left_third = 0...(image.width / 3)
    right_third = (2 * image.width / 3)...image.width

    assert_operator dark_pixel_count(image, x_range: left_third), :>, 100
    assert_operator dark_pixel_count(image, x_range: right_third), :>, 100
  ensure
    label_pdf&.cleanup!
    File.delete(png_path) if png_path && File.exist?(png_path)
  end

  test "24mm strip label grows when ar marker is attached" do
    width_without = Things::LabelPdf.new(thing: things(:router), printer: printers(:label_printer)).page_width_mm
    thing = attach_ar_anchor(things(:router))
    pdf = Things::LabelPdf.new(thing: thing, printer: printers(:label_printer))
    marker_width = Things::LabelPdf::AR_MARKER_GAP_MM + Things::LabelPdf::STRIP_24MM_ROLL_WIDTH_MM

    assert_in_delta width_without + marker_width, pdf.page_width_mm, 0.5
  ensure
    pdf&.cleanup! if pdf&.instance_variable_get(:@generated_path)
  end

  test "strip label expands width for long title line" do
    base_pdf = Things::LabelPdf.new(thing: things(:router), printer: printers(:label_printer))
    base_width = base_pdf.page_width_mm
    things(:router).update!(name: "A" * 45, owner: "B" * 45)
    pdf = Things::LabelPdf.new(thing: things(:router).reload, printer: printers(:label_printer))

    assert_operator pdf.page_width_mm, :>, base_width + 10
  ensure
    pdf&.cleanup! if pdf&.instance_variable_get(:@generated_path)
    base_pdf&.cleanup! if base_pdf&.instance_variable_get(:@generated_path)
  end

  test "cable tag prints hostname and ip on separate lines" do
    thing = things(:router)
    thing.update!(hostname: "router.local")
    pdf = Things::LabelPdf.new(thing: thing, printer: printers(:label_printer), layout: :cable_tag)
    lines = pdf.send(:cable_tag_label_lines)

    assert_equal [ "Router romkey", "router.local", "192.168.1.1" ], lines
  end

  test "uses site setting label margins by default" do
    SiteSetting.instance.update!(label_print_left_margin_mm: 2, label_print_right_margin_mm: 5, cable_tag_gap_mm: 8)
    pdf = Things::LabelPdf.new(thing: things(:router), printer: printers(:label_printer))

    assert_in_delta 2, pdf.left_margin_mm, 0.01
    assert_in_delta 5, pdf.right_margin_mm, 0.01
    assert_in_delta 8, pdf.cable_tag_gap_mm, 0.01
  ensure
    site_settings(:default).tap do |setting|
      setting.update!(label_print_left_margin_mm: 0, label_print_right_margin_mm: 3, cable_tag_gap_mm: 10)
    end
    pdf&.cleanup! if pdf&.instance_variable_get(:@generated_path)
  end

  test "accepts margin overrides" do
    pdf = Things::LabelPdf.new(
      thing: things(:router),
      printer: printers(:label_printer),
      layout: :cable_tag,
      margins: { left_margin_mm: 2, right_margin_mm: 5, cable_tag_gap_mm: 12 }
    )

    assert_in_delta 2, pdf.left_margin_mm, 0.01
    assert_in_delta 5, pdf.right_margin_mm, 0.01
    assert_in_delta 12, pdf.cable_tag_gap_mm, 0.01
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

  test "compact layout on 24mm strip uses a narrow square label" do
    label_pdf = Things::LabelPdf.new(thing: things(:router), printer: printers(:label_printer), layout: :compact)
    standard = Things::LabelPdf.new(thing: things(:router), printer: printers(:label_printer))

    assert_operator label_pdf.page_width_mm, :<, standard.page_width_mm
    assert_in_delta 24, label_pdf.page_height_mm, 0.1
    assert File.read(label_pdf.generate, 4).start_with?("%PDF")
  ensure
    label_pdf&.cleanup!
  end

  test "compact layout ignores attached ar marker" do
    thing = attach_ar_anchor(things(:router))
    compact = Things::LabelPdf.new(thing: thing, printer: printers(:label_printer), layout: :compact)
    standard = Things::LabelPdf.new(thing: thing, printer: printers(:label_printer))

    assert_in_delta compact.page_width_mm, Things::LabelPdf.new(thing: things(:router), printer: printers(:label_printer), layout: :compact).page_width_mm, 0.1
    assert_operator compact.page_width_mm, :<, standard.page_width_mm
  ensure
    compact&.cleanup!
    standard&.cleanup!
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

  def qr_vertical_extent(image, x_range:)
    top = nil
    bottom = nil

    x_range.each do |x|
      image.height.times do |y|
        next unless ChunkyPNG::Color.r(image[x, y]) < 200

        top = y if top.nil? || y < top
        bottom = y if bottom.nil? || y > bottom
      end
    end

    [ top || 0, bottom || 0 ]
  end
end
