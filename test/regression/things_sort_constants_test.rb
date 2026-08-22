require "test_helper"

# Constants declared inside a Data.define block attach to the enclosing module,
# so Things::ScanStats::SORTS used to overwrite Things::IndexQuery::SORTS once
# eager loading pulled in both services. Admin sorts then fell back to name.
class ThingsSortConstantsTest < ActiveSupport::TestCase
  setup do
    Rails.application.eager_load!
  end

  test "service constants stay out of the Things namespace" do
    assert_not Things.const_defined?(:SORTS, false)
    assert_not Things.const_defined?(:PUBLIC_SORTS, false)
    assert_not Things.const_defined?(:ADMIN_SORTS, false)
    assert_not Things.const_defined?(:DEFAULT_SORT, false)
    assert_not Things.const_defined?(:KEYS, false)
  end

  test "each service keeps its own sort list" do
    assert_equal %w[name hostname ip_address manufacturer model integration links photos labelled qr nfc visits], Things::IndexQuery::SORTS
    assert_equal %w[name qr nfc total visits], Things::ScanStats::SORTS
  end

  test "admin sorts survive loading every Things service" do
    %w[hostname ip_address manufacturer model integration links photos labelled qr nfc visits].each do |sort|
      assert_equal sort, Things::IndexQuery.call(sort: sort, admin: true).sort
    end
  end

  test "scan stats still rejects index-only sorts" do
    assert_equal "total", Things::ScanStats.call(sort: "hostname").sort
  end
end
