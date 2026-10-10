require "test_helper"

class ThingTemplateTest < ActiveSupport::TestCase
  test "requires a name" do
    template = ThingTemplate.new(name: "  ")

    assert_not template.valid?
    assert_includes template.errors[:name], "can't be blank"
  end

  test "names are unique ignoring case" do
    template = ThingTemplate.new(name: "raspberry pi 4")

    assert_not template.valid?
    assert_includes template.errors[:name], "has already been taken"
  end

  test "rejects non-http manufacturer links" do
    template = ThingTemplate.new(name: "Bad link", manufacturer_url: "javascript:alert(1)")

    assert_not template.valid?
    assert template.errors[:manufacturer_url].any?
  end

  test "from_thing keeps fields shared between instances" do
    router = things(:router)
    router.update!(manufacturer: "Ubiquiti", model: "UDM Pro", serial_number: "SN123", hostname: "router.lan")

    template = ThingTemplate.from_thing(router, name: "UDM Pro")
    template.save!

    assert_equal "Router", template.thing_name
    assert_equal router.description, template.description
    assert_equal router.notes, template.notes
    assert_equal "romkey", template.owner
    assert_equal "Ubiquiti", template.manufacturer
    assert_equal "UDM Pro", template.model
    assert_not template.has_attribute?(:serial_number)
    assert_not template.has_attribute?(:ip_address)
    assert_not template.has_attribute?(:hostname)
  end

  test "from_thing keeps standard and custom links but not Where" do
    template = ThingTemplate.from_thing(things(:router), name: "Router")

    assert_equal [ { "link_type" => "wiki", "url" => "https://wiki.example.com/router", "note" => "Front rack label" } ],
                 template.standard_links
    assert_equal [ { "link_type" => "custom", "title" => "Manual", "url" => "https://example.com/router-manual", "note" => nil } ],
                 template.custom_links
    assert_not template.links.any? { |data| data["link_type"] == "where" }
  end

  test "from_thing with an existing name replaces that template" do
    template = ThingTemplate.from_thing(things(:router), name: "raspberry pi 4")

    assert template.persisted?
    assert_equal thing_templates(:pi).id, template.id
    template.save!
    assert_equal "Router", template.reload.thing_name
    assert_equal "raspberry pi 4", template.name
  end

  test "build_thing pre-fills a new thing" do
    thing = thing_templates(:pi).build_thing

    assert thing.new_record?
    assert_equal "Raspberry Pi", thing.name
    assert_equal "Single-board computer", thing.description
    assert_equal "Raspberry Pi Ltd", thing.manufacturer
    assert_equal "Pi 4 Model B", thing.model
    assert thing.public_access?
    assert_nil thing.serial_number
    assert_nil thing.key
    assert_equal "https://wiki.example.com/pi", thing.link_for("wiki").url
    assert_equal "Setup guide", thing.link_for("wiki").note
    assert_equal [ "Datasheet" ], thing.custom_links.map(&:title)
  end

  test "a thing built from a template saves with its links" do
    thing = thing_templates(:pi).build_thing
    thing.save!

    assert_equal "https://wiki.example.com/pi", thing.links.find_by(link_type: :wiki).url
    assert_equal "https://example.com/pi-datasheet", thing.custom_links.first.url
    assert_match Thing::KEY_REGEX, thing.key
  end
end
