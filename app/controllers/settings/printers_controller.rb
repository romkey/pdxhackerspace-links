module Settings
  class PrintersController < BaseController
    before_action :set_printer, only: %i[show edit update destroy test_connection test_print]

    def index
      @printers = Printer.ordered
    end

    def show
    end

    def new
      @printer = Printer.new(
        enabled: true,
        printer_type: "cups",
        page_size: "label_brother_62mm",
        cups_server: Printer.default_cups_server
      )
      @cups_queues = []
      load_cups_queues if @printer.cups?
    end

    def edit
      @cups_queues = []
      load_cups_queues if @printer.cups?
    end

    def create
      @printer = Printer.new(printer_params)
      @cups_queues = []

      if @printer.save
        redirect_to settings_printer_path(@printer), notice: "Printer was created."
      else
        load_cups_queues if @printer.cups?
        render :new, status: :unprocessable_entity
      end
    end

    def update
      @cups_queues = []

      if @printer.update(printer_params)
        redirect_to settings_printer_path(@printer), notice: "Printer was updated."
      else
        load_cups_queues if @printer.cups?
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @printer.destroy!
      redirect_to settings_printers_path, notice: "Printer was deleted."
    end

    def cups_queues
      server = params[:server].to_s.strip
      return head :bad_request if server.blank? || server !~ Printer::CUPS_SERVER_FORMAT

      client = Cups::Client.new(server: server)
      reachable = client.reachable?

      render json: {
        reachable: reachable,
        queues: reachable ? client.queue_names : []
      }
    end

    def test_connection
      if @printer.command?
        redirect_to settings_printer_path(@printer), alert: "Command printers do not use CUPS."
        return
      end

      client = @printer.cups_client
      reachable = client.reachable?
      queues = reachable ? client.queue_names : []
      queue_found = queues.include?(@printer.cups_name)

      flash_type = reachable && queue_found ? :notice : :alert
      message = if !reachable
                  "Cannot reach CUPS at #{@printer.cups_server}."
                elsif !queue_found
                  "Connected to #{@printer.cups_server}, but queue #{@printer.cups_name} was not found."
                else
                  "Connected to #{@printer.cups_server}; queue #{@printer.cups_name} is available."
                end

      redirect_to settings_printer_path(@printer), flash_type => message
    end

    def test_print
      Printers::PrintTestLabel.call(printer: @printer)
      redirect_to settings_printer_path(@printer), notice: "Sent test label to #{@printer.name}."
    rescue Cups::Client::Error, Printers::CommandError => error
      redirect_to settings_printer_path(@printer), alert: error.message
    end

    private

    def set_printer
      @printer = Printer.find(params[:id])
    end

    def printer_params
      params.require(:printer).permit(
        :name,
        :printer_type,
        :cups_server,
        :cups_name,
        :page_size,
        :avery_template,
        :label_height_mm,
        :print_command,
        :description,
        :enabled
      )
    end

    def load_cups_queues
      return unless @printer.cups?

      @cups_client = @printer.cups_client
      @cups_queues = @cups_client.reachable? ? @cups_client.queue_names : []
    end
  end
end
