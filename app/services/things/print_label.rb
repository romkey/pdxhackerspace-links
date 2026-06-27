module Things
  class PrintLabel
    def self.call(thing:, printer:, copies: 1, cups_client: nil, command_runner: nil)
      raise ArgumentError, "Printer is disabled" unless printer.enabled?

      if printer.command?
        print_via_command(thing: thing, printer: printer, copies: copies, command_runner: command_runner)
      else
        print_via_cups(thing: thing, printer: printer, copies: copies, cups_client: cups_client)
      end
    end

    def self.print_via_cups(thing:, printer:, copies:, cups_client:)
      label_pdf = LabelPdf.new(thing: thing, printer: printer)
      path = label_pdf.generate
      client = cups_client || printer.cups_client

      client.print_file(
        path,
        printer: printer,
        title: thing.name,
        copies: copies,
        media: label_pdf.cups_media
      )
    ensure
      label_pdf&.cleanup!
    end

    def self.print_via_command(thing:, printer:, copies:, command_runner:)
      label_png = LabelPng.new(thing: thing, printer: printer)
      path = label_png.generate
      runner = command_runner || Printers::RunPrintCommand.method(:call)

      copies.times do
        runner.call(path: path, command: printer.print_command)
      end
    ensure
      label_png&.cleanup!
    end

    private_class_method :print_via_cups, :print_via_command
  end
end
