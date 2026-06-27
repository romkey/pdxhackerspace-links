require "test_helper"

class Things::DuplicateTest < ActiveSupport::TestCase
  test "creates copy with duplicate suffix in name" do
    copy = Things::Duplicate.call(thing: things(:router))

    assert_equal "Router (duplicate)", copy.name
    assert_equal things(:router).description, copy.description
    assert_equal things(:router).notes, copy.notes
    assert_equal things(:router).owner, copy.owner
    assert_equal things(:router).ip_address, copy.ip_address
  end

  test "copies links from source thing" do
    copy = Things::Duplicate.call(thing: things(:router))

    assert_equal things(:router).links_with_urls.map(&:display_title).sort,
                 copy.links_with_urls.map(&:display_title).sort
    assert_equal thing_links(:router_asset).url,
                 copy.links.find_by(link_type: :asset).url
    assert_equal thing_links(:router_custom).url,
                 copy.custom_links.first.url
  end

  test "does not copy blank links" do
    copy = Things::Duplicate.call(thing: things(:keyboard))

    assert_equal things(:keyboard).links_with_urls.size, copy.links_with_urls.size
    assert_nil copy.links.find_by(link_type: :asset)
  end

  test "copies standard link notes" do
    copy = Things::Duplicate.call(thing: things(:router))

    assert_equal "Front rack label", copy.links.find_by(link_type: :asset).note
  end

  test "copies ar marker and note" do
    attach_ar_anchor(things(:router))
    things(:router).update!(ar_anchor_note: "Scan marker")

    copy = Things::Duplicate.call(thing: things(:router))

    assert copy.ar_anchor.attached?
    assert_equal "Scan marker", copy.ar_anchor_note
  end
end
