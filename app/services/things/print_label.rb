module Things
  class PrintLabel
    def self.call(thing:, printer:, copies: 1, layout: :standard, cups_client: nil, command_runner: nil)
      raise ArgumentError, "Printer is disabled" unless printer.enabled?

      validate_layout!(thing: thing, printer: printer, layout: layout)

      if printer.command?
        print_via_command(thing: thing, printer: printer, copies: copies, layout: layout, command_runner: command_runner)
      else
        print_via_cups(thing: thing, printer: printer, copies: copies, layout: layout, cups_client: cups_client)
      end
    end

    def self.print_via_cups(thing:, printer:, copies:, layout:, cups_client:)
      label_pdf = LabelPdf.new(thing: thing, printer: printer, layout: layout)
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

    def self.print_via_command(thing:, printer:, copies:, layout:, command_runner:)
      label_png = LabelPng.new(thing: thing, printer: printer, layout: layout)
      path = label_png.generate
      runner = command_runner || Printers::RunPrintCommand.method(:call)

      copies.times do
        runner.call(path: path, command: printer.print_command, precut_before: printer.precut_before?)
      end
    ensure
      label_png&.cleanup!
    end

    def self.validate_layout!(thing:, printer:, layout:)
      layout = layout.to_sym
      return if layout == :standard

      raise ArgumentError, "Invalid layout: #{layout}" unless LabelPdf::LAYOUTS.include?(layout)
      raise ArgumentError, "Printer does not support cable tags" unless printer.cable_tag_capable?
      raise ArgumentError, "Cable tags require an IP address or hostname" if thing.label_ip_line.blank?
    end

    private_class_method :print_via_cups, :print_via_command, :validate_layout!
  end
end
