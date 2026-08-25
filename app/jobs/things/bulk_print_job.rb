module Things
  class BulkPrintJob < ApplicationJob
    queue_as :default

    def perform(thing_ids:, printer_id:, layout: "standard", copies: 1, mark_labelled: false)
      printer = Printer.enabled.find_by(id: printer_id)
      return if printer.nil?

      layout = layout.to_sym
      copies = copies.to_i
      copies = 1 if copies < 1

      Thing.where(id: thing_ids).find_each do |thing|
        Things::PrintLabel.call(
          thing: thing,
          printer: printer,
          copies: copies,
          layout: layout,
          mark_labelled: mark_labelled
        )
      rescue ArgumentError, Cups::Client::Error, Printers::CommandError => error
        Rails.logger.warn("Bulk print skipped thing #{thing.id}: #{error.message}")
      end
    end
  end
end
