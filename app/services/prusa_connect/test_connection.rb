module PrusaConnect
  # Probes the printer list so a misconfigured refresh token is reported before an import.
  class TestConnection
    Result = Data.define(:printer_count, :errors) do
      def success?
        errors.empty?
      end

      def message
        return errors.join("; ") if errors.any?

        count = printer_count.to_i
        return "Connected to Prusa Connect, but no printers were found." if count.zero?

        "Connected to Prusa Connect — #{count} #{'printer'.pluralize(count)} available."
      end
    end

    def self.call(prusa_connect_account:, client: nil)
      new(prusa_connect_account: prusa_connect_account, client: client).call
    end

    def initialize(prusa_connect_account:, client: nil)
      @prusa_connect_account = prusa_connect_account
      @client = client
    end

    def call
      count = client.printer_count
      Result.new(printer_count: count, errors: [])
    rescue Client::Error => error
      Result.new(printer_count: nil, errors: [ error.message ])
    end

    private

    attr_reader :prusa_connect_account

    def client
      @client ||= prusa_connect_account.client
    end
  end
end
