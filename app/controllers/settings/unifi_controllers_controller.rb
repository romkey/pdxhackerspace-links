module Settings
  class UnifiControllersController < BaseController
    before_action :set_unifi_controller, only: %i[show edit update destroy test_connection import]

    def index
      @unifi_controllers = UnifiController.ordered
    end

    def show
      @unifi_devices = @unifi_controller.unifi_devices.includes(:thing).ordered
      @unifi_devices = @unifi_devices.active unless show_archived?
    end

    def new
      @unifi_controller = UnifiController.new(
        port: 443,
        enabled: true,
        network_enabled: true,
        protect_enabled: true,
        auto_create_things: true
      )
    end

    def edit
    end

    def create
      @unifi_controller = UnifiController.new(unifi_controller_params)

      if @unifi_controller.save
        redirect_to settings_unifi_controller_path(@unifi_controller), notice: "UniFi controller was added."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def update
      if @unifi_controller.update(unifi_controller_params)
        redirect_to settings_unifi_controller_path(@unifi_controller), notice: "UniFi controller was updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @unifi_controller.destroy!
      redirect_to settings_unifi_controllers_path, notice: "UniFi controller was deleted."
    end

    def test_connection
      result = Unifi::TestConnection.call(unifi_controller: @unifi_controller)

      redirect_to settings_unifi_controller_path(@unifi_controller),
                  (result.success? ? :notice : :alert) => result.message
    end

    def import
      unless @unifi_controller.enabled?
        return redirect_to settings_unifi_controller_path(@unifi_controller),
                           alert: "Enable #{@unifi_controller.name} before running an import."
      end

      @unifi_controller.update!(last_sync_status: "running", last_sync_message: "Import queued.")
      Unifi::ImportJob.perform_later(@unifi_controller.id)

      redirect_to settings_unifi_controller_path(@unifi_controller),
                  notice: "Import started for #{@unifi_controller.name}. Reload to see the results."
    end

    private

    def set_unifi_controller
      @unifi_controller = UnifiController.find(params[:id])
    end

    def show_archived?
      params[:archived] == "1"
    end
    helper_method :show_archived?

    def unifi_controller_params
      permitted = params.require(:unifi_controller).permit(
        :name,
        :host,
        :port,
        :api_key,
        :verify_tls,
        :network_enabled,
        :protect_enabled,
        :auto_create_things,
        :description,
        :enabled
      )

      # An existing key is never rendered back into the form, so a blank field means "leave it alone".
      permitted.delete(:api_key) if @unifi_controller&.persisted? && permitted[:api_key].blank?
      permitted
    end
  end
end
