require "test_helper"

class ArStandardLinkRegressionTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:local_admin))
  end

  test "edit form includes ar standard link field" do
    get edit_thing_path(things(:router))

    assert_response :success
    assert_select "input[type=hidden][name=?][value=?]", "thing[links_attributes][4][link_type]", "ar"
    assert_select "input[name=?]", "thing[links_attributes][4][url]"
    assert_select "input[name=?]", "thing[links_attributes][4][note]"
  end

  test "show displays ar standard link with url and note" do
    things(:router).links.create!(link_type: :ar, url: "https://example.com/ar", note: "Room-scale view")

    get thing_path(things(:router))

    assert_response :success
    assert_select "a[href=?]", "https://example.com/ar", text: /AR/
    assert_select ".text-12", text: "Room-scale view"
  end

  test "creates thing with ar standard link" do
    post things_path, params: {
      thing: {
        name: "AR Thing",
        links_attributes: {
          "0" => { link_type: "asset", url: "" },
          "1" => { link_type: "wiki", url: "" },
          "2" => { link_type: "slack", url: "" },
          "3" => { link_type: "where", url: "" },
          "4" => { link_type: "ar", url: "https://example.com/ar-experience", note: "Use iOS app" }
        }
      }
    }

    thing = Thing.order(:created_at).last
    assert_redirected_to thing_path(thing)
    ar_link = thing.links.find_by(link_type: :ar)
    assert_equal "https://example.com/ar-experience", ar_link.url
    assert_equal "Use iOS app", ar_link.note
  end

  test "duplicate copies ar standard link" do
    things(:router).links.create!(link_type: :ar, url: "https://example.com/ar", note: "Room view")

    copy = Things::Duplicate.call(thing: things(:router))

    ar_link = copy.links.find_by(link_type: :ar)
    assert_equal "https://example.com/ar", ar_link.url
    assert_equal "Room view", ar_link.note
  end
end
