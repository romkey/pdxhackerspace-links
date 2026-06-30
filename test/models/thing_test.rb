require "test_helper"

class ThingTest < ActiveSupport::TestCase
  test "requires a name" do
    thing = Thing.new
    assert_not thing.valid?
    assert_includes thing.errors[:name], "can't be blank"
  end

  test "builds standard links for new records" do
    thing = Thing.new
    assert_equal ThingLink::STANDARD_TYPES.keys.sort, thing.links.map(&:link_type).sort
  end

  test "links_with_urls returns standard and custom links that have urls" do
    thing = things(:keyboard)
    titles = thing.links_with_urls.map(&:display_title)

    assert_includes titles, "Wiki"
    assert_includes titles, "Slack"
    assert_not_includes titles, "Asset"
  end

  test "links_for_display includes standard links with notes and no url" do
    link = thing_links(:router_asset)
    link.update!(url: "", note: "Physical tag location")
    thing = things(:router).reload

    assert_includes thing.links_for_display.map(&:display_title), "Asset"
    assert_not_includes thing.links_with_urls.map(&:display_title), "Asset"
  end

  test "preserves standard links with notes but no url after save" do
    thing = Thing.create!(name: "Tagged", links_attributes: [
      { link_type: :wiki, url: "", note: "Shelf B" }
    ])

    assert thing.links.exists?(link_type: :wiki)
    assert_equal "Shelf B", thing.links.find_by(link_type: :wiki).note
  end

  test "label title line includes owner when set" do
    router = things(:router)
    assert_equal "Router romkey", router.label_title_line
    assert_equal "192.168.1.1", router.label_ip_line
  end

  test "label title line omits blank owner" do
    assert_equal "Keyboard", things(:keyboard).label_title_line
    assert_nil things(:keyboard).label_ip_line
  end

  test "scan total count sums qr and nfc counts" do
    thing = things(:router)
    thing.update!(qr_scan_count: 4, nfc_scan_count: 2)

    assert_equal 6, thing.scan_total_count
  end

  test "accepts a valid IPv4 address" do
    thing = things(:keyboard)
    thing.ip_address = "10.0.0.1"
    assert thing.valid?
  end

  test "accepts a hostname" do
    thing = things(:keyboard)
    thing.ip_address = "router.local"
    assert thing.valid?
  end

  test "accepts a single-label hostname" do
    thing = things(:keyboard)
    thing.ip_address = "router"
    assert thing.valid?
  end

  test "accepts a fully qualified domain name" do
    thing = things(:keyboard)
    thing.ip_address = "host.example.com"
    assert thing.valid?
  end

  test "allows a blank ip address or hostname" do
    thing = things(:keyboard)
    thing.ip_address = ""
    assert thing.valid?
  end

  test "rejects an invalid ip address or hostname" do
    thing = things(:keyboard)
    thing.ip_address = "not a host!"
    assert_not thing.valid?
    assert_includes thing.errors[:ip_address], "must be a valid IPv4 address or hostname"
  end

  test "search matches name, description, owner, notes, and links" do
    assert_includes Thing.search("keyboard"), things(:keyboard)
    assert_includes Thing.search("network"), things(:router)
    assert_includes Thing.search("Manual"), things(:router)
    assert_includes Thing.search("romkey"), things(:router)
    assert_includes Thing.search("192.168.1.1"), things(:router)
    assert_includes Thing.search("front of shelf"), things(:router)
    assert_not_includes Thing.search("keyboard"), things(:router)
    assert_equal Thing.count, Thing.search("").count
  end

  test "assigns positions to custom links on save" do
    thing = Thing.create!(
      name: "Positioned Thing",
      links_attributes: [
        { link_type: :custom, title: "First", url: "https://example.com/first" },
        { link_type: :custom, title: "Second", url: "https://example.com/second" }
      ]
    )

    assert_equal [ 0, 1 ], thing.custom_links.map(&:position)
  end

  test "purges blank links after save" do
    thing = Thing.create!(name: "Test Thing", links_attributes: [
      { link_type: :wiki, url: "https://example.com/wiki" },
      { link_type: :asset, url: "" }
    ])

    assert thing.links.exists?(link_type: :wiki)
    assert_not thing.links.exists?(link_type: :asset)
  end
end
