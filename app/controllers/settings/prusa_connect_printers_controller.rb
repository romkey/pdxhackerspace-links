module Settings
  class PrusaConnectPrintersController < BaseController
    def update
      printer = PrusaConnectPrinter.find(params[:id])
      ignored = ActiveModel::Type::Boolean.new.cast(params[:ignored])

      if ignored
        printer.update!(ignored: true, thing: nil)
        notice = "#{printer.display_name} will be skipped by future imports."
      else
        printer.update!(ignored: false)
        PrusaConnect::SyncThing.call(
          prusa_connect_printer: printer,
          auto_create: printer.prusa_connect_account.auto_create_things?
        )
        notice = "#{printer.display_name} will be imported again."
      end

      redirect_to settings_prusa_connect_account_path(printer.prusa_connect_account), notice: notice
    end
  end
end
