require "test_helper"

class NfcWriteEncodingRegressionTest < ActiveSupport::TestCase
  CONTROLLER_PATH = Rails.root.join("app/javascript/controllers/nfc_write_controller.js")

  test "nfc write encodes mime record data as ArrayBufferView" do
    source = CONTROLLER_PATH.read

    assert_includes source, "encodeRecordData"
    assert_includes source, "TextEncoder"
    assert_no_match(/mediaType: "application\/json", data: this\.jsonValue/, source)
  end
end
