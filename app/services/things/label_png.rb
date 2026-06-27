require "open3"
require "fileutils"

module Things
  class LabelPng
    DPI = 300

    def initialize(thing:, printer:, qr_url: nil)
      @thing = thing
      @printer = printer
      @qr_url = qr_url
      @label_pdf = LabelPdf.new(thing: thing, printer: printer, qr_url: qr_url)
    end

    def generate
      @generated_path ||= build_png
    end

    def png_data
      data = File.binread(generate)
      cleanup!
      data
    end

    def cleanup!
      return unless @generated_path

      File.delete(@generated_path) if File.exist?(@generated_path)
      @generated_path = nil
      @label_pdf.cleanup!
    end

    delegate :page_width_mm, :page_height_mm, :landscape?, to: :@label_pdf

    private

    attr_reader :thing, :printer, :qr_url, :label_pdf

    def build_png
      pdf_path = label_pdf.generate
      output = Tempfile.new([ "thing-label", ".png" ])
      output.close
      base_path = output.path.sub(/\.png\z/, "")

      _stdout, stderr, status = Open3.capture3(
        "pdftoppm", "-png", "-singlefile",
        "-rx", DPI.to_f.to_s, "-ry", DPI.to_f.to_s,
        pdf_path, base_path
      )

      unless status.success?
        message = stderr.strip.presence || "Failed to convert label PDF to PNG"
        raise Printers::CommandError, message
      end

      generated = "#{base_path}.png"
      FileUtils.mv(generated, output.path) unless File.exist?(output.path)
      output.path
    end
  end
end
