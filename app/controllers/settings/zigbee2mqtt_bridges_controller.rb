module Settings
  class Zigbee2mqttBridgesController < BaseController
    before_action :set_zigbee2mqtt_bridge, only: %i[show edit update destroy test_connection import]

    def index
      @zigbee2mqtt_bridges = Zigbee2mqttBridge.ordered
    end

    def show
      @zigbee2mqtt_devices = @zigbee2mqtt_bridge.zigbee2mqtt_devices.includes(:thing).ordered
      @zigbee2mqtt_devices = @zigbee2mqtt_devices.active unless show_archived?
    end

    def new
      @zigbee2mqtt_bridge = Zigbee2mqttBridge.new(
        mqtt_port: 1883,
        base_topic: "zigbee2mqtt",
        enabled: true,
        auto_create_things: true,
        skip_disabled_devices: true,
        import_unknown_last_seen: true
      )
    end

    def edit
    end

    def create
      @zigbee2mqtt_bridge = Zigbee2mqttBridge.new(zigbee2mqtt_bridge_params)

      if @zigbee2mqtt_bridge.save
        redirect_to settings_zigbee2mqtt_bridge_path(@zigbee2mqtt_bridge), notice: "Zigbee2MQTT bridge was added."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def update
      if @zigbee2mqtt_bridge.update(zigbee2mqtt_bridge_params)
        redirect_to settings_zigbee2mqtt_bridge_path(@zigbee2mqtt_bridge), notice: "Zigbee2MQTT bridge was updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @zigbee2mqtt_bridge.destroy!
      redirect_to settings_zigbee2mqtt_bridges_path, notice: "Zigbee2MQTT bridge was deleted."
    end

    def test_connection
      result = Zigbee2mqtt::TestConnection.call(zigbee2mqtt_bridge: @zigbee2mqtt_bridge)

      redirect_to settings_zigbee2mqtt_bridge_path(@zigbee2mqtt_bridge),
                  (result.success? ? :notice : :alert) => result.message
    end

    def import
      @zigbee2mqtt_bridge.update!(last_sync_status: "running", last_sync_message: "Import queued.")
      Zigbee2mqtt::ImportJob.perform_later(@zigbee2mqtt_bridge.id)

      redirect_to settings_zigbee2mqtt_bridge_path(@zigbee2mqtt_bridge),
                  notice: "Import started for #{@zigbee2mqtt_bridge.name}. Reload to see the results."
    end

    private

    def set_zigbee2mqtt_bridge
      @zigbee2mqtt_bridge = Zigbee2mqttBridge.find(params[:id])
    end

    def show_archived?
      params[:archived] == "1"
    end
    helper_method :show_archived?

    def zigbee2mqtt_bridge_params
      permitted = params.require(:zigbee2mqtt_bridge).permit(
        :name,
        :description,
        :enabled,
        :mqtt_host,
        :mqtt_port,
        :mqtt_username,
        :mqtt_password,
        :mqtt_tls,
        :base_topic,
        :auto_create_things,
        :skip_disabled_devices,
        :last_seen_limit_days,
        :import_unknown_last_seen
      )

      permitted.delete(:mqtt_password) if @zigbee2mqtt_bridge&.persisted? && permitted[:mqtt_password].blank?
      permitted
    end
  end
end
