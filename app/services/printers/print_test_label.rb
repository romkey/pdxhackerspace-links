module Printers
  class PrintTestLabel
    def self.call(printer:, cups_client: nil, command_runner: nil)
      thing = TestLabel.for_printer(printer)
      qr_url = Rails.application.routes.url_helpers.root_url(**AppHost.url_options)

      if printer.command?
        print_via_command(thing: thing, printer: printer, qr_url: qr_url, command_runner: command_runner)
      else
        print_via_cups(thing: thing, printer: printer, qr_url: qr_url, cups_client: cups_client)
      end
    end

    def self.print_via_cups(thing:, printer:, qr_url:, cups_client:)
      label_pdf = Things::LabelPdf.new(thing: thing, printer: printer, qr_url: qr_url)
      path = label_pdf.generate
      client = cups_client || printer.cups_client

      client.print_file(
        path,
        printer: printer,
        title: thing.name,
        copies: 1,
        media: label_pdf.cups_media
      )
    ensure
      label_pdf&.cleanup!
    end

    def self.print_via_command(thing:, printer:, qr_url:, command_runner:)
      label_png = Things::LabelPng.new(thing: thing, printer: printer, qr_url: qr_url)
      path = label_png.generate
      runner = command_runner || RunPrintCommand.method(:call)

      runner.call(path: path, command: printer.print_command)
    ensure
      label_png&.cleanup!
    end

    private_class_method :print_via_cups, :print_via_command
  end
end
