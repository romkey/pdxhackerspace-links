require "test_helper"

class ThingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:local_admin))
  end

  test "index lists things" do
    get things_path
    assert_response :success
    assert_select "td", text: things(:keyboard).name
  end

  test "show displays thing details" do
    get thing_path(things(:keyboard))
    assert_response :success
    assert_select "h1", things(:keyboard).name
    assert_select "a[href=?]", thing_links(:keyboard_wiki).url
  end

  test "creates thing with standard and custom links" do
    assert_difference -> { Thing.count }, 1 do
      post things_path, params: {
        thing: {
          name: "Printer",
          description: "Office printer",
          links_attributes: {
            "0" => { link_type: "asset", url: "https://example.com/asset" },
            "1" => { link_type: "wiki", url: "" },
            "2" => { link_type: "slack", url: "" },
            "3" => { link_type: "where", url: "" },
            "4" => { link_type: "custom", title: "Support", url: "https://example.com/support", position: 0 }
          }
        }
      }
    end

    thing = Thing.order(:created_at).last
    assert_redirected_to thing_path(thing)
    assert_equal "Printer", thing.name
    assert_equal 2, thing.links_with_urls.size
    assert_equal "Support", thing.links.select(&:link_custom?).first.display_title
  end

  test "updates thing" do
    patch thing_path(things(:router)), params: {
      thing: {
        name: "Core Router",
        links_attributes: {
          "0" => { id: thing_links(:router_asset).id, link_type: "asset", url: thing_links(:router_asset).url }
        }
      }
    }

    assert_redirected_to thing_path(things(:router))
    assert_equal "Core Router", things(:router).reload.name
  end

  test "destroys thing" do
    assert_difference -> { Thing.count }, -1 do
      delete thing_path(things(:router))
    end

    assert_redirected_to things_path
  end

  test "requires authentication" do
    delete logout_path

    get things_path
    assert_redirected_to login_path
  end
end
