require "test_helper"

class Things::NfcTagPayloadTest < ActiveSupport::TestCase
  setup do
    @original_max_bytes = ENV["NFC_TAG_MAX_BYTES"]
    @thing = things(:router)
    @builder = Things::NfcTagPayload.new(@thing)
    @url = @builder.send(:thing_url, @thing, **@builder.send(:route_url_options))
    @fields = @builder.send(:build_fields, @url)
  end

  teardown do
    if @original_max_bytes
      ENV["NFC_TAG_MAX_BYTES"] = @original_max_bytes
    else
      ENV.delete("NFC_TAG_MAX_BYTES")
    end
  end

  test "builds url and json for a thing" do
    result = Things::NfcTagPayload.call(@thing)

    assert_match(%r{/things/#{@thing.id}\z}, result.url)
    payload = JSON.parse(result.json)
    assert_equal result.url, payload["url"]
    assert_equal "Router", payload["name"]
    assert_equal "romkey", payload["owner"]
    assert_equal "192.168.1.1", payload["ip_address"]
    assert_equal "Main network router", payload["description"]
    assert_equal "Rack 2, front of shelf", payload["notes"]
    assert_not result.json_truncated
    assert result.estimated_bytes.positive?
  end

  test "omits blank optional fields from json" do
    result = Things::NfcTagPayload.call(things(:keyboard))
    payload = JSON.parse(result.json)

    assert_equal "Keyboard", payload["name"]
    assert_not payload.key?("owner")
    assert_not payload.key?("ip_address")
    assert_not payload.key?("notes")
  end

  test "truncates metadata to fit tag size limit" do
    full_size = @builder.send(:estimate_ndef_bytes, @url, @fields)
    ENV["NFC_TAG_MAX_BYTES"] = (full_size - 1).to_s

    result = Things::NfcTagPayload.call(@thing)
    payload = JSON.parse(result.json)

    assert result.json_truncated
    assert_equal "Router", payload["name"]
    assert_match(%r{/things/#{@thing.id}\z}, result.url)
    assert result.estimated_bytes <= ENV["NFC_TAG_MAX_BYTES"].to_i
  end
end
