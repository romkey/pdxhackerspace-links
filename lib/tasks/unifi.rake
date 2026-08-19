namespace :unifi do
  desc "Import devices from every enabled UniFi controller and populate things"
  task import: :environment do
    controllers = UnifiController.enabled.ordered

    if controllers.empty?
      puts "No enabled UniFi controllers configured."
      next
    end

    controllers.each do |unifi_controller|
      result = Unifi::Import.call(unifi_controller: unifi_controller)
      puts "#{unifi_controller.name}: #{result.status} — #{result.summary}"
    end
  end
end
