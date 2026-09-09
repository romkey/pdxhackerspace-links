module PrusaConnect
  # A printer from Prusa Connect, normalized into the shape stored on PrusaConnectPrinter.
  PrinterRecord = Data.define(
    :external_id,
    :name,
    :printer_model,
    :printer_type_name,
    :serial_number,
    :firmware,
    :ieee_address,
    :hostname,
    :location,
    :team_name,
    :state,
    :payload
  ) do
    def self.from_payload(payload)
      network = payload["network_info"].is_a?(Hash) ? payload["network_info"] : {}
      mac = network["mac"].presence || network["lan_mac"]
      firmware = payload["firmware"].presence || payload["firmware_version"]

      new(
        external_id: payload["uuid"].presence || payload["id"].to_s,
        name: payload["name"],
        printer_model: payload["printer_model"],
        printer_type_name: payload["printer_type_name"],
        serial_number: payload["sn"],
        firmware: firmware,
        ieee_address: Integrations::HardwareAddress.normalize(mac),
        hostname: network["hostname"],
        location: payload["location"],
        team_name: payload["team_name"],
        state: payload["printer_state"].presence || payload["state"],
        payload: payload
      )
    end

    def to_attributes
      {
        name: name,
        printer_model: printer_model,
        printer_type_name: printer_type_name,
        serial_number: serial_number,
        firmware: firmware,
        ieee_address: ieee_address,
        hostname: hostname,
        location: location,
        team_name: team_name,
        state: state,
        payload: payload
      }
    end
  end
end
