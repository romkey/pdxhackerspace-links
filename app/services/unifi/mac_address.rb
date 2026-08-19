module Unifi
  # The Network API returns colon-separated MACs and the Protect API returns bare
  # hex, so both are normalized before they are used to match devices to things.
  module MacAddress
    module_function

    def normalize(value)
      hex = value.to_s.downcase.gsub(/[^0-9a-f]/, "")
      return nil unless hex.length == 12

      hex.scan(/../).join(":")
    end
  end
end
