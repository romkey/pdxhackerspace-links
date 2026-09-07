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

  test "two text lines each take half the strip height" do
    pdf = Things::LabelPdf.new(thing: things(:router), printer: printers(:label_printer))
    lines = pdf.send(:strip_style_label_lines)
    expected_mm = (24 - Things::LabelPdf::TEXT_LINE_GAP_MM) / 2

    assert_equal 2, lines.size
    assert_in_delta expected_mm, text_row_height_mm(pdf, lines.size), 0.01
  end

  test "three text lines split the strip height evenly" do
    pdf = Things::LabelPdf.new(thing: things(:router), printer: printers(:label_printer))
    expected_mm = (24 - (2 * Things::LabelPdf::TEXT_LINE_GAP_MM)) / 3

    assert_in_delta expected_mm, text_row_height_mm(pdf, 3), 0.01
  end

  test "hostname and ip share the bottom text line" do
    thing = things(:router)
    thing.update!(hostname: "router.local")
    pdf = Things::LabelPdf.new(thing: thing, printer: printers(:label_printer))

    assert_equal [ "Router - romkey", "router.local - 192.168.1.1" ], pdf.send(:strip_style_label_lines)
  end

  test "text row height is capped on wide rolls" do
    pdf = Things::LabelPdf.new(thing: things(:router), printer: printers(:brother_printer))

    assert_in_delta Things::LabelPdf::MAX_TEXT_ROW_MM, text_row_height_mm(pdf, 2), 0.01
  end

  test "strip label text fills the strip height" do
    label_pdf = Things::LabelPdf.new(thing: things(:router), printer: printers(:label_printer))
    path = label_pdf.generate
    png_path = rasterize_label_pdf(path)
    image = ChunkyPNG::Image.from_file(png_path)
    text_start = (image.width * (Things::LabelPdf::STRIP_24MM_ROLL_WIDTH_MM / label_pdf.page_width_mm)).ceil
    text_top, text_bottom = qr_vertical_extent(image, x_range: text_start...image.width)

    assert_operator text_bottom - text_top, :>=, (image.height * 0.7).round
  ensure
    label_pdf&.cleanup!
    File.delete(png_path) if png_path && File.exist?(png_path)
  end

  test "strip label prints the owner after the name with a dash" do
    label_pdf = Things::LabelPdf.new(thing: things(:router), printer: printers(:label_printer))
    text = extract_label_pdf_text(label_pdf.generate)

    assert_includes text, "Router - romkey"
  ensure
    label_pdf&.cleanup!
  end

  test "brother roll label prints the owner with the name" do
    label_pdf = Things::LabelPdf.new(thing: things(:router), printer: printers(:brother_printer))
    text = extract_label_pdf_text(label_pdf.generate)

    assert_includes text, "Router"
    assert_includes text, "romkey"
  ensure
    label_pdf&.cleanup!
  end

  test "avery label prints the owner with the name" do
    label_pdf = Things::LabelPdf.new(thing: things(:router), printer: printers(:office_laser))
    text = extract_label_pdf_text(label_pdf.generate)

    assert_includes text, "Router"
    assert_includes text, "romkey"
  ensure
    label_pdf&.cleanup!
  end

  test "compact label prints the owner with the name" do
    label_pdf = Things::LabelPdf.new(
      thing: things(:router),
      printer: printers(:label_printer),
      layout: :compact
    )
    text = extract_label_pdf_text(label_pdf.generate)

    assert_includes text, "Router"
    assert_includes text, "romkey"
  ensure
    label_pdf&.cleanup!
  end

  test "labels without an owner print only the name" do
    label_pdf = Things::LabelPdf.new(thing: things(:keyboard), printer: printers(:label_printer))
    text = extract_label_pdf_text(label_pdf.generate)

    assert_includes text, "Keyboard"
  ensure
    label_pdf&.cleanup!
  end

  test "cable tag prints hostname and ip together on the bottom line" do
    thing = things(:router)
    thing.update!(hostname: "router.local")
    pdf = Things::LabelPdf.new(thing: thing, printer: printers(:label_printer), layout: :cable_tag)
    lines = pdf.send(:cable_tag_label_lines)

    assert_equal [ "Router - romkey", "router.local - 192.168.1.1" ], lines
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

  test "qr only layout is a square strip label with no text" do
    label_pdf = Things::LabelPdf.new(thing: things(:router), printer: printers(:label_printer), layout: :qr_only)
    path = label_pdf.generate
    expected_width = (label_pdf.left_margin_mm + 24 + label_pdf.right_margin_mm).round

    assert label_pdf.landscape?
    assert_in_delta 24, label_pdf.page_height_mm, 0.1
    assert_in_delta expected_width, label_pdf.page_width_mm, 0.1
    assert_equal expected_width, label_pdf.cups_media[/Custom\.24x(\d+)mm/, 1].to_i
    assert_equal "", extract_label_pdf_text(path).strip
  ensure
    label_pdf&.cleanup!
  end

  test "qr only layout fills the strip height with the qr code" do
    label_pdf = Things::LabelPdf.new(thing: things(:router), printer: printers(:label_printer), layout: :qr_only)
    path = label_pdf.generate
    png_path = rasterize_label_pdf(path)
    image = ChunkyPNG::Image.from_file(png_path)
    qr_top, qr_bottom = qr_vertical_extent(image, x_range: 0...(image.width / 3))

    assert_operator qr_bottom - qr_top, :>=, (image.height * 0.9).round
  ensure
    label_pdf&.cleanup!
    File.delete(png_path) if png_path && File.exist?(png_path)
  end

  test "qr only layout ignores attached ar markers" do
    thing = attach_ar_anchor(things(:router))
    qr_only = Things::LabelPdf.new(thing: thing, printer: printers(:label_printer), layout: :qr_only)
    standard = Things::LabelPdf.new(thing: thing, printer: printers(:label_printer))
    expected_width = (qr_only.left_margin_mm + 24 + qr_only.right_margin_mm).round

    assert_in_delta expected_width, qr_only.page_width_mm, 0.1
    assert_operator qr_only.page_width_mm, :<, standard.page_width_mm
  end

  test "qr only layout renders on portrait fixed labels without text" do
    label_pdf = Things::LabelPdf.new(thing: things(:router), printer: printers(:office_laser), layout: :qr_only)
    path = label_pdf.generate

    assert File.read(path, 4).start_with?("%PDF")
    assert_equal "", extract_label_pdf_text(path).strip
    assert_qr_visible_in_label_pdf(path, region: :any)
  ensure
    label_pdf&.cleanup!
  end

  test "qr only layout is offered and labelled" do
    assert_includes Things::LabelPdf::LAYOUTS, :qr_only
    assert_equal "QR code only", Things::LabelPdf.layout_label(:qr_only)
  end

  test "compact layout renders on portrait fixed labels" do
    label_pdf = Things::LabelPdf.new(thing: things(:keyboard), printer: printers(:office_laser), layout: :compact)
    path = label_pdf.generate

    assert File.exist?(path)
    assert File.read(path, 4).start_with?("%PDF")
    assert_operator label_pdf.page_height_mm, :>, 0
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

  def text_row_height_mm(label_pdf, line_count)
    label_pdf.send(:text_row_height_pt, line_count) / Things::LabelPdf::MM_TO_PT
  end

  def extract_label_pdf_text(path)
    stdout, stderr, status = Open3.capture3("pdftotext", "-layout", path, "-")
    raise "pdftotext failed: #{stderr}" unless status.success?

    stdout
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
