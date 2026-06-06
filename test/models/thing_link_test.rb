require "test_helper"

class ThingLinkTest < ActiveSupport::TestCase
  test "standard link display title comes from type" do
    link = thing_links(:keyboard_wiki)
    assert_equal "Wiki", link.display_title
  end

  test "custom link requires title and url" do
    link = ThingLink.new(thing: things(:router), link_type: :custom, title: "Docs")
    assert_not link.valid?
    assert_includes link.errors[:url], "can't be blank"
  end

  test "allows only one standard link of each type per thing" do
    link = ThingLink.new(
      thing: things(:keyboard),
      link_type: :wiki,
      url: "https://example.com/duplicate"
    )

    assert_not link.valid?
    assert_includes link.errors[:link_type], "has already been taken"
  end

  test "validates url format when present" do
    link = ThingLink.new(
      thing: things(:router),
      link_type: :slack,
      url: "not-a-url"
    )

    assert_not link.valid?
    assert_includes link.errors[:url], "is invalid"
  end
end
