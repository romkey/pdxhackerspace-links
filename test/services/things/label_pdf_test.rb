require "test_helper"

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
  ensure
    label_pdf&.cleanup!
  end

  test "pdf_data returns bytes and cleans up temp file" do
    label_pdf = Things::LabelPdf.new(thing: things(:router), printer: printers(:label_printer))

    data = label_pdf.pdf_data
    assert data.start_with?("%PDF")
    assert_not label_pdf.instance_variable_get(:@generated_path)
  end
end
