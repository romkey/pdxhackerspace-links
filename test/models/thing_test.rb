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

  test "search matches name, description, and links" do
    assert_includes Thing.search("keyboard"), things(:keyboard)
    assert_includes Thing.search("network"), things(:router)
    assert_includes Thing.search("Manual"), things(:router)
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

    assert_equal [0, 1], thing.custom_links.map(&:position)
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
