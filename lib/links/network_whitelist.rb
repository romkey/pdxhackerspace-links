require "ipaddr"

module Links
  module NetworkWhitelist
    module_function

    def configured?
      networks.any?
    end

    def includes?(ip)
      return false if ip.blank?
      return false unless configured?

      address = IPAddr.new(ip)
      networks.any? { |network| network.include?(address) }
    rescue IPAddr::InvalidAddressError
      false
    end

    def networks
      @networks ||= parse(ENV.fetch("NETWORK_WHITELIST", ""))
    end

    def parse(value)
      value.to_s.split(/[,\s]+/).filter_map do |entry|
        next if entry.blank?

        IPAddr.new(entry)
      rescue IPAddr::InvalidAddressError
        nil
      end
    end

    def reset!
      @networks = nil
    end
  end
end
