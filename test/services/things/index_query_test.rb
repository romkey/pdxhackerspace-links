require "test_helper"

class Things::IndexQueryTest < ActiveSupport::TestCase
  test "defaults to sorting by name ascending" do
    query = Things::IndexQuery.call

    assert_equal "name", query.sort
    assert_equal "asc", query.direction
    assert_equal [ things(:keyboard).name, things(:router).name ], query.scope.map(&:name)
  end

  test "searches things by query" do
    query = Things::IndexQuery.call(search: "keyboard")

    assert_equal 1, query.total_count
    assert_equal [ things(:keyboard).name ], query.scope.map(&:name)
  end

  test "sorts by hostname descending" do
    things(:keyboard).update!(hostname: "zebra.local")
    things(:router).update!(hostname: "alpha.local")

    query = Things::IndexQuery.call(sort: "hostname", direction: "desc")

    assert_equal [ things(:keyboard).name, things(:router).name ], query.scope.map(&:name)
  end

  test "sorts by hostname descending with blank hostnames last" do
    things(:keyboard).update!(hostname: nil)
    things(:router).update!(hostname: "alpha.local")

    query = Things::IndexQuery.call(sort: "hostname", direction: "desc")

    assert_equal [ things(:router).name, things(:keyboard).name ], query.scope.map(&:name)
  end

  test "sorts by ip address descending with blank addresses last" do
    query = Things::IndexQuery.call(sort: "ip_address", direction: "desc")

    assert_equal [ things(:router).name, things(:keyboard).name ], query.scope.map(&:name)
  end

  test "sorts by links count descending when counts differ" do
    things(:keyboard).links.find_by(link_type: :slack).update!(url: "")

    query = Things::IndexQuery.call(sort: "links", direction: "desc")

    assert_equal [ things(:router).name, things(:keyboard).name ], query.scope.map(&:name)
  end

  test "sorts by ip address ascending" do
    query = Things::IndexQuery.call(sort: "ip_address", direction: "asc")

    assert_equal [ things(:router).name, things(:keyboard).name ], query.scope.map(&:name)
  end

  test "sorts by links count descending" do
    query = Things::IndexQuery.call(sort: "links", direction: "desc")

    assert_operator query.scope.first.links_count, :>=, query.scope.last.links_count
  end

  test "sorts by photos count ascending" do
    query = Things::IndexQuery.call(sort: "photos", direction: "asc")

    assert_operator query.scope.first.photos_count, :<=, query.scope.last.photos_count
  end

  test "allows admin sort columns when admin is true" do
    things(:router).update!(visit_count: 10, nfc_scan_count: 3, qr_scan_count: 5)
    things(:keyboard).update!(visit_count: 1, nfc_scan_count: 0, qr_scan_count: 0)

    query = Things::IndexQuery.call(sort: "visits", direction: "desc", admin: true)

    assert_equal "visits", query.sort
    assert_equal things(:router).name, query.scope.first.name
  end

  test "ignores admin sort columns when admin is false" do
    query = Things::IndexQuery.call(sort: "visits", direction: "desc", admin: false)

    assert_equal "name", query.sort
  end

  test "ignores invalid sort parameters" do
    query = Things::IndexQuery.call(sort: "invalid", direction: "sideways")

    assert_equal "name", query.sort
    assert_equal "asc", query.direction
  end
end
