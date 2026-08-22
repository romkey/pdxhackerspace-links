require "test_helper"

class Things::IndexFiltersTest < ActiveSupport::TestCase
  test "parses yes and no filter values" do
    filters = Things::IndexFilters.parse(links: "yes", photos: "no", ip_address: "maybe")

    assert_equal({ links: "yes", photos: "no" }, filters.values)
  end

  test "filters things with links" do
    query = Things::IndexQuery.call(filters: { links: "yes" })

    assert_includes query.scope.map(&:name), things(:keyboard).name
    assert_includes query.scope.map(&:name), things(:router).name
  end

  test "filters things without links" do
    Thing.create!(name: "Empty thing")

    query = Things::IndexQuery.call(filters: { links: "no" })

    assert_equal [ "Empty thing" ], query.scope.map(&:name)
  end

  test "filters things with ip address" do
    query = Things::IndexQuery.call(filters: { ip_address: "yes" })

    assert_equal [ things(:router).name ], query.scope.map(&:name)
  end

  test "filters things without ip address" do
    query = Things::IndexQuery.call(filters: { ip_address: "no" })

    assert_equal [ things(:keyboard).name ], query.scope.map(&:name)
  end

  test "filters things with mac address" do
    query = Things::IndexQuery.call(filters: { mac_address: "yes" })

    assert_equal [ things(:router).name ], query.scope.map(&:name)
  end

  test "filters things with wiki link" do
    query = Things::IndexQuery.call(filters: { wiki: "yes" })

    assert_equal [ things(:keyboard).name ], query.scope.map(&:name)
  end

  test "filters things without wiki link" do
    query = Things::IndexQuery.call(filters: { wiki: "no" })

    assert_equal [ things(:router).name ], query.scope.map(&:name)
  end

  test "filters things with custom url link" do
    query = Things::IndexQuery.call(filters: { url: "yes" })

    assert_equal [ things(:router).name ], query.scope.map(&:name)
  end

  test "stacks multiple filters" do
    query = Things::IndexQuery.call(filters: { links: "yes", ip_address: "yes" })

    assert_equal [ things(:router).name ], query.scope.map(&:name)
  end

  test "ignores unknown filter keys" do
    filters = Things::IndexFilters.parse(unknown: "yes", links: "yes")

    assert_equal({ links: "yes" }, filters.values)
  end
end
