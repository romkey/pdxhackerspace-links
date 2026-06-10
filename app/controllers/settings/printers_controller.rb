module Settings
  class PrintersController < BaseController
    before_action :set_printer, only: %i[show edit update destroy]

    def index
      @printers = Printer.ordered
      @site_setting = SiteSetting.instance
    end

    def show
    end

    def new
      @printer = Printer.new(enabled: true, page_size: Printer::PAGE_SIZES.keys.first)
      load_cups_queues
    end

    def edit
      load_cups_queues
    end

    def create
      @printer = Printer.new(printer_params)

      if @printer.save
        redirect_to settings_printer_path(@printer), notice: "Printer was created."
      else
        load_cups_queues
        render :new, status: :unprocessable_entity
      end
    end

    def update
      if @printer.update(printer_params)
        redirect_to settings_printer_path(@printer), notice: "Printer was updated."
      else
        load_cups_queues
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @printer.destroy!
      redirect_to settings_printers_path, notice: "Printer was deleted."
    end

    private

    def set_printer
      @printer = Printer.find(params[:id])
    end

    def printer_params
      params.require(:printer).permit(:name, :cups_name, :page_size, :description, :enabled)
    end

    def load_cups_queues
      @site_setting = SiteSetting.instance
      @cups_client = Cups::Client.new(server: @site_setting.cups_server)
      @cups_queues = @cups_client.reachable? ? @cups_client.queue_names : []
    end
  end
end
