require "test_helper"

class ThingsNfcWriteTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:local_admin))
  end

  test "show page includes nfc payload for logged in users" do
    get thing_path(things(:router))

    assert_response :success
    assert_match "Write NFC", response.body
    assert_match "data-controller=\"nfc-write\"", response.body
    assert_match Things::NfcTagPayload.call(things(:router)).url, response.body
  end

  test "index row includes nfc payload for logged in users" do
    get things_path

    assert_response :success
    assert_match "data-controller=\"nfc-write\"", response.body
    assert_match Things::NfcTagPayload.call(things(:router)).url, response.body
  end

  test "guest does not see nfc controls" do
    delete logout_path

    with_network_whitelist("192.168.0.0/16") do
      get thing_path(things(:router)), env: from_network("192.168.1.50")

      assert_response :success
      assert_no_match "data-controller=\"nfc-write\"", response.body
      assert_no_match "Write NFC", response.body
    end
  end
end
