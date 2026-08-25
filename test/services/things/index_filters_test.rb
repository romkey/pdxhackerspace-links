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

  test "filters things with ieee address" do
    query = Things::IndexQuery.call(filters: { ieee_address: "yes" })

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

  test "filters things by integration source" do
    query = Things::IndexQuery.call(filters: { integration: [ "unifi" ] })

    assert_equal [ things(:router).name ], query.scope.map(&:name)
  end

  test "filters things with no integration source" do
    query = Things::IndexQuery.call(filters: { integration: [ "none" ] })

    assert_equal [ things(:keyboard).name ], query.scope.map(&:name)
  end

  test "filters labelled things" do
    things(:router).mark_labelled!

    yes_query = Things::IndexQuery.call(filters: { labelled: "yes" })
    no_query = Things::IndexQuery.call(filters: { labelled: "no" })

    assert_equal [ things(:router).name ], yes_query.scope.map(&:name)
    assert_includes no_query.scope.map(&:name), things(:keyboard).name
    assert_not_includes no_query.scope.map(&:name), things(:router).name
  end

  test "ignores unknown filter keys" do
    filters = Things::IndexFilters.parse(unknown: "yes", links: "yes")

    assert_equal({ links: "yes" }, filters.values)
  end
end
