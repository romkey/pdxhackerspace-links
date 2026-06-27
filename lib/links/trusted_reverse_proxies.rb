require "ipaddr"

module Links
  module TrustedReverseProxies
    module_function

    def configured?
      networks.any?
    end

    def networks
      @networks ||= parse(ENV.fetch("TRUSTED_REVERSE_PROXIES", ""))
    end

    def parse(value)
      value.to_s.split(/[,\s]+/).filter_map do |entry|
        next if entry.blank?

        IPAddr.new(entry)
      rescue IPAddr::InvalidAddressError
        nil
      end
    end

    def all
      ActionDispatch::RemoteIp::TRUSTED_PROXIES + networks
    end

    def apply!
      Rails.application.config.action_dispatch.trusted_proxies = all
    end

    def reset!
      @networks = nil
    end
  end
end
