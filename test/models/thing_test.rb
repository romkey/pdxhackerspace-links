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
    assert_includes Thing.search("fda50693-f4c2-4a1b-8fb9-9d9458836f36"), things(:router)
    assert_not_includes Thing.search("keyboard"), things(:router)
    assert_equal Thing.count, Thing.search("").count
  end

  test "allows blank ble beacon uuid" do
    thing = things(:keyboard)
    thing.ble_beacon_uuid = ""
    assert thing.valid?
  end

  test "normalizes ble beacon uuid to lowercase" do
    thing = things(:keyboard)
    thing.ble_beacon_uuid = "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
    assert thing.valid?
    assert_equal "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee", thing.ble_beacon_uuid
  end

  test "rejects invalid ble beacon uuid" do
    thing = things(:keyboard)
    thing.ble_beacon_uuid = "not-a-uuid"
    assert_not thing.valid?
    assert_includes thing.errors[:ble_beacon_uuid], "must be a valid UUID"
  end

  test "requires unique ble beacon uuid" do
    thing = things(:keyboard)
    thing.ble_beacon_uuid = things(:router).ble_beacon_uuid
    assert_not thing.valid?
    assert_includes thing.errors[:ble_beacon_uuid], "has already been taken"
  end

  test "allows blank slug" do
    thing = things(:router)
    thing.slug = ""
    assert thing.valid?
  end

  test "normalizes slug to lowercase" do
    thing = things(:router)
    thing.slug = "Core-Router"
    assert thing.valid?
    assert_equal "core-router", thing.slug
  end

  test "rejects invalid slug format" do
    thing = things(:router)
    thing.slug = "bad slug!"
    assert_not thing.valid?
    assert_includes thing.errors[:slug], "must contain only lowercase letters, numbers, and hyphens"
  end

  test "rejects reserved slug" do
    thing = things(:router)
    thing.slug = "by_beacon"
    assert_not thing.valid?
    assert_includes thing.errors[:slug], "is reserved"
  end

  test "requires unique slug" do
    thing = things(:router)
    thing.slug = things(:keyboard).slug
    assert_not thing.valid?
    assert_includes thing.errors[:slug], "has already been taken"
  end

  test "assigns unique key on create" do
    thing = Thing.create!(name: "Keyed Thing", links_attributes: [
      { link_type: :wiki, url: "https://example.com/wiki" }
    ])

    assert_match Thing::KEY_REGEX, thing.key
  end

  test "rejects invalid key format" do
    thing = things(:router)
    thing.key = "12345678"
    assert_not thing.valid?
    assert_includes thing.errors[:key], "is invalid"
  end

  test "requires unique key" do
    thing = things(:router)
    thing.key = things(:keyboard).key
    assert_not thing.valid?
    assert_includes thing.errors[:key], "has already been taken"
  end

  test "rejects reserved key" do
    thing = things(:router)
    thing.key = "settings"
    assert_not thing.valid?
    assert_includes thing.errors[:key], "is reserved"
  end

  test "find_by_param finds by key" do
    assert_equal things(:keyboard), Thing.find_by_param!(things(:keyboard).key)
  end

  test "search matches key" do
    assert_includes Thing.search(things(:router).key), things(:router)
  end

  test "to_param returns slug when set" do
    assert_equal "front-door-keyboard", things(:keyboard).to_param
  end

  test "to_param returns id when slug is blank" do
    assert_equal things(:router).id.to_s, things(:router).to_param
  end

  test "find_by_slug_or_id finds by slug" do
    assert_equal things(:keyboard), Thing.find_by_slug_or_id!("front-door-keyboard")
  end

  test "find_by_slug_or_id finds by id" do
    assert_equal things(:router), Thing.find_by_slug_or_id!(things(:router).id)
  end

  test "search matches slug" do
    assert_includes Thing.search("front-door"), things(:keyboard)
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

  test "normalizes a MAC address to lowercase colon form" do
    thing = Thing.create!(name: "Switch", mac_address: "94-2A-6F-26-C6-CB")

    assert_equal "94:2a:6f:26:c6:cb", thing.mac_address
  end

  test "accepts a blank MAC address" do
    thing = Thing.new(name: "No MAC", mac_address: "  ")

    assert thing.valid?
    assert_nil thing.mac_address
  end

  test "rejects a MAC address that is not six octets" do
    thing = Thing.new(name: "Bad MAC", mac_address: "94:2a:6f")

    assert_not thing.valid?
    assert_includes thing.errors[:mac_address], "must be a valid MAC address"
  end

  test "requires a unique MAC address" do
    thing = Thing.new(name: "Duplicate MAC", mac_address: things(:router).mac_address)

    assert_not thing.valid?
    assert_includes thing.errors[:mac_address], "has already been taken"
  end

  test "finds things by MAC address" do
    assert_includes Thing.search("94:2a:6f"), things(:router)
  end

  test "deleting a thing stops its UniFi devices from recreating it" do
    thing = things(:router)
    device = unifi_devices(:rack_switch)

    thing.destroy!

    device.reload
    assert device.ignored?
    assert_nil device.thing_id
  end
end
