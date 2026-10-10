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

  test "apply_to fills only blank fields" do
    router = things(:router)
    template = thing_templates(:pi)

    filled = template.apply_to(router)

    assert_equal "Main network router", router.description
    assert_equal "romkey", router.owner
    assert_equal "Raspberry Pi Ltd", router.manufacturer
    assert_equal "Pi 4 Model B", router.model
    assert_equal template.manufacturer_url, router.manufacturer_url
    assert_not router.public_access
    assert_includes filled, "Manufacturer"
    assert_includes filled, "Manufacturer link"
    assert_not_includes filled, "Description"
    assert_not_includes filled, "Owner"
    assert_not_includes filled, "Public"
  end

  test "apply_to fills blank parts of standard links and keeps existing values" do
    router = things(:router)
    thing_templates(:pi).apply_to(router)
    router.save!

    wiki = router.links.reload.find_by!(link_type: "wiki")
    assert_equal "https://wiki.example.com/router", wiki.url
    assert_equal "Front rack label", wiki.note
  end

  test "apply_to merges in custom links" do
    router = things(:router)

    filled = thing_templates(:pi).apply_to(router)
    router.save!

    assert_includes filled, "Datasheet"
    titles = router.links.reload.custom.order(:position).pluck(:title)
    assert_equal %w[Manual Datasheet], titles
    assert_equal "https://example.com/pi-datasheet", router.links.find_by!(title: "Datasheet").url
  end

  test "apply_to fills a matching custom link instead of duplicating it" do
    router = things(:router)
    template = ThingTemplate.new(name: "Manual note", links: [
      { "link_type" => "custom", "title" => "manual", "url" => "https://example.com/other", "note" => "Chapter 3" }
    ])

    filled = template.apply_to(router)
    router.save!

    manual = router.links.reload.custom.sole
    assert_equal "https://example.com/router-manual", manual.url
    assert_equal "Chapter 3", manual.note
    assert_equal [ "manual" ], filled
  end

  test "apply_to adds standard links the thing lacks" do
    keyboard = things(:keyboard)
    keyboard.links.find_by!(link_type: "wiki").destroy
    keyboard.reload

    thing_templates(:pi).apply_to(keyboard)
    keyboard.save!

    wiki = keyboard.links.reload.find_by!(link_type: "wiki")
    assert_equal "https://wiki.example.com/pi", wiki.url
    assert_equal "Setup guide", wiki.note
  end

  test "apply_to reports nothing when everything is already set" do
    router = things(:router)
    template = ThingTemplate.new(name: "Same", owner: "someone else")

    assert_empty template.apply_to(router)
    assert_not router.changed?
  end
end
