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

  test "purges blank links after save" do
    thing = Thing.create!(name: "Test Thing", links_attributes: [
      { link_type: :wiki, url: "https://example.com/wiki" },
      { link_type: :asset, url: "" }
    ])

    assert thing.links.exists?(link_type: :wiki)
    assert_not thing.links.exists?(link_type: :asset)
  end
end
