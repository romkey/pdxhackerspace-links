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

  test "filters things with slack link" do
    query = Things::IndexQuery.call(filters: { slack: "yes" })

    assert_equal [ things(:keyboard).name ], query.scope.map(&:name)
  end

  test "filters things without slack link" do
    query = Things::IndexQuery.call(filters: { slack: "no" })

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

  test "excludes things from an integration source" do
    query = Things::IndexQuery.call(filters: { integration_exclude: [ "unifi" ] })

    assert_equal [ things(:keyboard).name ], query.scope.map(&:name)
  end

  test "excludes things with no integration source" do
    query = Things::IndexQuery.call(filters: { integration_exclude: [ "none" ] })

    assert_equal [ things(:router).name ], query.scope.map(&:name)
  end

  test "combines included and excluded integration sources" do
    query = Things::IndexQuery.call(filters: { integration: [ "unifi", "none" ], integration_exclude: [ "none" ] })

    assert_equal [ "unifi", "none" ], query.filters.sources
    assert_equal [], query.filters.excluded_sources
    assert_equal [ things(:router).name, things(:keyboard).name ].sort, query.scope.map(&:name).sort
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

  test "filters things on a wired host" do
    assert_equal [ things(:router).name ], Things::IndexQuery.call(filters: { wired: "yes" }).scope.map(&:name)
    assert_not_includes Things::IndexQuery.call(filters: { wired: "no" }).scope.map(&:name), things(:router).name
  end

  test "filters things on a Wi-Fi host" do
    assert_empty Things::IndexQuery.call(filters: { wifi: "yes" }).scope

    unifi_hosts(:laptop_host).update!(thing: things(:keyboard))

    assert_equal [ things(:keyboard).name ], Things::IndexQuery.call(filters: { wifi: "yes" }).scope.map(&:name)
  end

  test "ignores archived hosts when filtering on connection" do
    unifi_hosts(:router_host).update!(archived_at: Time.current)

    assert_empty Things::IndexQuery.call(filters: { wired: "yes" }).scope
  end

  test "filters things on an online host" do
    assert_equal [ things(:router).name ], Things::IndexQuery.call(filters: { online: "yes" }).scope.map(&:name)
  end

  test "filters things with a reserved IP address" do
    things(:keyboard).update!(reserved_ip_address: "192.168.1.20")

    assert_equal [ things(:keyboard).name ],
                 Things::IndexQuery.call(filters: { reserved_ip_address: "yes" }).scope.map(&:name)
  end
end
