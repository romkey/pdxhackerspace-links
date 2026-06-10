require "test_helper"

class ThingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:local_admin))
  end

  test "index lists things" do
    get things_path
    assert_response :success
    assert_select "td", text: things(:keyboard).name
    assert_select "nav input[type=search][name=q]"
  end

  test "index searches things by query" do
    get things_path, params: { q: "keyboard" }
    assert_response :success
    assert_select "td", text: things(:keyboard).name
    assert_select "td", text: things(:router).name, count: 0
    assert_select "input[type=search][value=?]", "keyboard"
  end

  test "index search matches description and links" do
    get things_path, params: { q: "network" }
    assert_response :success
    assert_select "td", text: things(:router).name

    get things_path, params: { q: "Manual" }
    assert_response :success
    assert_select "td", text: things(:router).name
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

  test "creates thing with multiple custom links" do
    post things_path, params: {
      thing: {
        name: "Label Printer",
        links_attributes: {
          "0" => { link_type: "asset", url: "" },
          "1" => { link_type: "wiki", url: "" },
          "2" => { link_type: "slack", url: "" },
          "3" => { link_type: "where", url: "" },
          "4" => { link_type: "custom", title: "Support", url: "https://example.com/support" },
          "5" => { link_type: "custom", title: "Drivers", url: "https://example.com/drivers" }
        }
      }
    }

    thing = Thing.order(:created_at).last
    assert_redirected_to thing_path(thing)
    assert_equal 2, thing.custom_links.size
    assert_equal ["Support", "Drivers"], thing.custom_links.map(&:display_title)
    assert_equal [0, 1], thing.custom_links.map(&:position)
  end

  test "updates thing with additional custom links" do
    patch thing_path(things(:router)), params: {
      thing: {
        name: things(:router).name,
        links_attributes: {
          "0" => { id: thing_links(:router_asset).id, link_type: "asset", url: thing_links(:router_asset).url },
          "1" => { id: thing_links(:router_custom).id, link_type: "custom", title: "Manual", url: "https://example.com/router-manual" },
          "2" => { link_type: "custom", title: "Firmware", url: "https://example.com/router-firmware" }
        }
      }
    }

    assert_redirected_to thing_path(things(:router))
    router = things(:router).reload
    assert_equal 2, router.custom_links.size
    assert_equal ["Manual", "Firmware"], router.custom_links.map(&:display_title)
  end

  test "edit form includes add custom link control" do
    get edit_thing_path(things(:router))
    assert_response :success
    assert_select "button[data-action='nested-form#add']", text: "+ Add custom link"
    assert_select "input[value=?]", "Manual"
  end

  test "create failure re-renders form with custom links" do
    post things_path, params: {
      thing: {
        name: "",
        links_attributes: {
          "0" => { link_type: "custom", title: "Support", url: "https://example.com/support" }
        }
      }
    }

    assert_response :unprocessable_entity
    assert_select "button[data-action='nested-form#add']"
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
