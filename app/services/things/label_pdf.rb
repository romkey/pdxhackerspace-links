require "prawn"
require "rqrcode"
require "stringio"

module Things
  class LabelPdf
    MM_TO_PT = 72.0 / 25.4
    IN_TO_PT = 72.0
    LETTER_WIDTH = 8.5 * IN_TO_PT
    LETTER_HEIGHT = 11 * IN_TO_PT
    STRIP_24MM_ROLL_WIDTH_MM = 24
    STRIP_24MM_MARGIN_MM = 1
    STRIP_24MM_TEXT_ROW_MM = 6
    STRIP_24MM_TEXT_GAP_MM = 0.75
    STRIP_24MM_TEXT_MIN_WIDTH_MM = 28
    STRIP_24MM_FEED_MARGIN_MM = 3
    STRIP_24MM_TEXT_SIZE = 10
    LANDSCAPE_FEED_MARGIN_MM = 3
    LANDSCAPE_TEXT_MIN_WIDTH_MM = 28
    LANDSCAPE_TEXT_SIZE = 11

    PAGE_LAYOUTS = {
      "label_brother_12mm" => { width_mm: 12, height_mm: 40 },
      "label_brother_29mm" => { width_mm: 29, height_mm: 40 },
      "label_brother_38mm" => { width_mm: 38, height_mm: 50 },
      "label_brother_62mm" => { width_mm: 62, height_mm: 50 },
      "label_brother_62x100" => { width_mm: 62, height_mm: 100 },
      "label_brother_102mm" => { width_mm: 102, height_mm: 50 },
      "label_strip_24mm" => { width_mm: 24, dynamic_width: true },
      "label_4x6" => { width_in: 4, height_in: 6 },
      "letter" => { letter: true },
      "receipt_80mm" => { width_mm: 80, height_mm: 120 }
    }.freeze

    def initialize(thing:, printer:, qr_url: nil)
      @thing = thing
      @printer = printer
      @qr_url = qr_url
    end

    def generate
      @generated_path ||= build_pdf
    end

    def pdf_data
      data = File.binread(generate)
      cleanup!
      data
    end

    def cleanup!
      return unless @generated_path

      File.delete(@generated_path) if File.exist?(@generated_path)
      @generated_path = nil
    end

    def page_width_mm
      return 215.9 if letter_page?
      return landscape_label_width_mm if landscape_label?

      layout = page_layout
      return layout[:width_in] * 25.4 if layout[:width_in]

      layout[:width_mm]
    end

    def page_height_mm
      return 279.4 if letter_page?
      return roll_width_mm if landscape_label?

      layout = page_layout
      return layout[:height_in] * 25.4 if layout[:height_in]

      layout[:height_mm]
    end

    def landscape?
      landscape_label?
    end

    def cups_media
      return printer.cups_media unless printer.continuous_roll?

      roll = printer.roll_width_mm
      feed_mm = (landscape_label? ? page_width_mm : page_height_mm).round
      "Custom.#{roll}x#{feed_mm}mm"
    end

    private

    attr_reader :thing, :printer

    def build_pdf
      file = Tempfile.new([ "thing-label", ".pdf" ])
      file.binmode

      Prawn::Document.generate(file.path, margin: 0, page_size: [ page_width, page_height ]) do |pdf|
        if letter_page?
          render_avery_label(pdf)
        elsif strip_style_label?
          render_strip_style_label(pdf)
        elsif landscape_label?
          render_landscape_roll_label(pdf)
        else
          render_label(pdf, bounds: [ 0, page_height, page_width, 0 ])
        end
      end

      file.path
    end

    def page_layout
      return command_page_layout if command_label?

      PAGE_LAYOUTS.fetch(printer.page_size)
    end

    def command_page_layout
      { width_mm: printer.label_height_mm, dynamic_width: true }
    end

    def letter_page?
      page_layout[:letter]
    end

    def strip_24mm_label?
      printer.page_size == "label_strip_24mm"
    end

    def command_label?
      printer.command?
    end

    def strip_style_label?
      strip_24mm_label? || command_label?
    end

    def landscape_label?
      printer.landscape_label?
    end

    def roll_width_mm
      printer.roll_width_mm || page_layout[:width_mm]
    end

    def page_width
      mm_to_pt(page_width_mm)
    end

    def page_height
      mm_to_pt(page_height_mm)
    end

    def landscape_label_width_mm
      return strip_24mm_width_mm if strip_24mm_label?

      margin = STRIP_24MM_MARGIN_MM
      qr = roll_width_mm - (2 * margin)
      (margin + qr + STRIP_24MM_TEXT_GAP_MM + LANDSCAPE_TEXT_MIN_WIDTH_MM + margin + LANDSCAPE_FEED_MARGIN_MM).round
    end

    def strip_24mm_width_mm
      margin = STRIP_24MM_MARGIN_MM
      qr = strip_roll_width_mm - (2 * margin)
      (margin + qr + STRIP_24MM_TEXT_GAP_MM + STRIP_24MM_TEXT_MIN_WIDTH_MM + margin + STRIP_24MM_FEED_MARGIN_MM).round
    end

    def strip_roll_width_mm
      strip_24mm_label? ? STRIP_24MM_ROLL_WIDTH_MM : roll_width_mm
    end

    def render_strip_style_label(pdf)
      render_landscape_roll_label(
        pdf,
        top_line: thing.label_title_line,
        bottom_line: strip_style_bottom_line
      )
    end

    def strip_style_bottom_line
      return thing.label_ip_line if strip_24mm_label? || command_label?

      thing.links_with_urls.first&.display_title
    end

    def render_landscape_roll_label(pdf, top_line: thing.name, bottom_line: thing.links_with_urls.first&.display_title)
      margin = mm(STRIP_24MM_MARGIN_MM)
      feed_margin = mm(landscape_feed_margin_mm)
      strip_height = page_height
      qr_size = strip_height - (2 * margin)
      qr_bottom = margin

      draw_qr_code(pdf, x: margin, y: qr_bottom, size: qr_size)

      text_left = margin + qr_size + mm(STRIP_24MM_TEXT_GAP_MM)
      text_width = page_width - text_left - margin - feed_margin
      text_rows = bottom_line.present? ? 2 : 1
      text_row_height = mm(STRIP_24MM_TEXT_ROW_MM)
      text_gap = mm(STRIP_24MM_TEXT_GAP_MM)
      text_block_height = (text_rows * text_row_height) + ((text_rows - 1) * text_gap)
      row_top = margin + ((strip_height - (2 * margin) - text_block_height) / 2) + text_block_height
      font_size = strip_text_size

      pdf.text_box top_line.to_s,
                   at: [ text_left, row_top ],
                   width: text_width,
                   height: text_row_height,
                   size: font_size,
                   style: :bold,
                   overflow: :truncate,
                   single_line: true,
                   valign: :center

      return if bottom_line.blank?

      row_top -= text_row_height + text_gap
      pdf.text_box bottom_line.to_s,
                   at: [ text_left, row_top ],
                   width: text_width,
                   height: text_row_height,
                   size: font_size,
                   overflow: :truncate,
                   single_line: true,
                   valign: :center,
                   color: "444444"
    end

    def draw_qr_code(pdf, x:, y:, size:)
      pdf.image StringIO.new(qr_png_data(size)), at: [ x, y + size ], width: size, height: size
    end

    def qr_png_data(size_pt)
      pixel_size = [ (size_pt / 72.0 * 300).round, 120 ].max
      RQRCode::QRCode.new(thing_url, level: :l).as_png(
        resize_gte_to: false,
        resize_exactly_to: false,
        fill: "white",
        color: "black",
        size: pixel_size,
        border_modules: 1
      ).to_s
    end

    def strip_text_size
      strip_24mm_label? ? STRIP_24MM_TEXT_SIZE : LANDSCAPE_TEXT_SIZE
    end

    def landscape_feed_margin_mm
      strip_24mm_label? ? STRIP_24MM_FEED_MARGIN_MM : LANDSCAPE_FEED_MARGIN_MM
    end

    def render_avery_label(pdf)
      config = printer.avery_template_config || Printer::AVERY_TEMPLATES["avery_5160"]
      bounds = avery_label_bounds(config, row: 0, col: 0)
      render_label(pdf, bounds: bounds)
    end

    def avery_label_bounds(config, row:, col:)
      margin_left = 0.1875 * IN_TO_PT
      margin_top = 0.5 * IN_TO_PT
      label_width = config[:label_width_in] * IN_TO_PT
      label_height = config[:label_height_in] * IN_TO_PT
      columns = config[:columns]
      rows = config[:rows]
      horizontal_gap = columns > 1 ? (LETTER_WIDTH - (2 * margin_left) - (columns * label_width)) / (columns - 1) : 0
      vertical_gap = rows > 1 ? (LETTER_HEIGHT - (2 * margin_top) - (rows * label_height)) / (rows - 1) : 0

      x = margin_left + (col * (label_width + horizontal_gap))
      y = LETTER_HEIGHT - margin_top - label_height - (row * (label_height + vertical_gap))

      [ x, y + label_height, label_width, label_height ]
    end

    def render_label(pdf, bounds:)
      x, top, width, height = bounds
      padding = [ width * 0.08, 6 ].max
      content_width = width - (2 * padding)
      content_height = height - (2 * padding)
      qr_size = [ content_width * 0.45, content_height * 0.45, 72 ].min
      show_qr = qr_size >= 24 && content_width >= 36

      pdf.bounding_box([ x + padding, top - padding ], width: content_width, height: content_height) do
        pdf.text thing.name, size: title_size(content_width), style: :bold, align: :center

        if show_qr
          pdf.move_down 4
          pdf.bounding_box([ (content_width - qr_size) / 2, pdf.cursor ], width: qr_size, height: qr_size) do
            draw_qr_code(pdf, x: 0, y: 0, size: qr_size)
          end
          pdf.move_down qr_size
        end

        subtitle = thing.links_with_urls.first&.display_title
        if subtitle.present? && pdf.cursor > 12
          pdf.move_down 4
          pdf.text subtitle, size: [ title_size(content_width) - 2, 6 ].max, align: :center, color: "666666"
        end
      end
    end

    def title_size(content_width)
      if content_width < 40
        8
      elsif content_width < 80
        10
      elsif content_width < 140
        12
      else
        14
      end
    end

    def thing_url
      @qr_url || Rails.application.routes.url_helpers.thing_url(
        thing,
        **AppHost.url_options
      )
    end

    def mm_to_pt(value)
      (value.to_f * MM_TO_PT).round(4)
    end

    def mm(value)
      mm_to_pt(value)
    end
  end
end
