namespace :integrations do
  desc "Import devices from every enabled integration"
  task import: :environment do
    unifi_controllers = UnifiController.enabled.ordered
    zigbee_bridges = Zigbee2mqttBridge.enabled.ordered

    if unifi_controllers.empty? && zigbee_bridges.empty?
      puts "No enabled integrations configured."
      next
    end

    unifi_controllers.each do |unifi_controller|
      result = Unifi::Import.call(unifi_controller: unifi_controller)
      puts "UniFi #{unifi_controller.name}: #{result.status} — #{result.summary}"
    end

    zigbee_bridges.each do |bridge|
      result = Zigbee2mqtt::Import.call(zigbee2mqtt_bridge: bridge)
      puts "Zigbee2MQTT #{bridge.name}: #{result.status} — #{result.summary}"
    end
  end
end
