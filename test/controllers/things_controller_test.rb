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
    assert_select "a[href*=?]", "label_preview"
    assert_select "button", text: "Duplicate"
  end

  test "show displays standard link notes" do
    get thing_path(things(:router))

    assert_response :success
    assert_select ".list-group-item", text: /Asset/
    assert_select ".list-group-item", text: /Front rack label/
  end

  test "show displays ar anchor when attached" do
    attach_ar_anchor(things(:router))
    things(:router).update!(ar_anchor_note: "Scan from the front")

    get thing_path(things(:router))

    assert_response :success
    assert_select ".h-section-label", text: "AR Anchor"
    assert_select "img[src]"
    assert_select ".text-12", text: "Scan from the front"
  end

  test "label preview shows scaled pdf and print action" do
    get label_preview_thing_path(things(:router), printer_id: printers(:label_printer).id)

    assert_response :success
    assert_select "h1", "Label preview"
    assert_select "iframe[src=?]", label_preview_thing_path(things(:router), printer_id: printers(:label_printer).id, format: :pdf)
    assert_select "button", text: /Print label/
  end

  test "label preview pdf format returns inline pdf" do
    get label_preview_thing_path(things(:router), printer_id: printers(:label_printer).id, format: :pdf)

    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert response.body.start_with?("%PDF")
    assert_match(/inline/, response.headers["Content-Disposition"])
  end

  test "index includes inline row actions when printers are enabled" do
    get things_path
    assert_response :success
    assert_select "a[href=?]", edit_thing_path(things(:keyboard))
    assert_select "button", text: "Duplicate"
    assert_select "button", text: "Delete"
    assert_select "button", text: "Print"
    assert_select "button[aria-label*=Actions]", count: 0
  end

  test "duplicate creates copy and redirects to edit" do
    assert_difference -> { Thing.count }, 1 do
      post duplicate_thing_path(things(:router))
    end

    copy = Thing.order(:created_at).last
    assert_redirected_to edit_thing_path(copy)
    assert_equal "Router (duplicate)", copy.name
    assert_equal things(:router).links_with_urls.size, copy.links_with_urls.size
    assert_equal "Duplicated as “Router (duplicate)”.", flash[:notice]
  end

  test "print sends label to selected printer from index row" do
    with_fake_cups_client do
      post print_thing_path(things(:keyboard)), params: { printer_id: printers(:brother_printer).id }
    end

    assert_redirected_to thing_path(things(:keyboard))
    assert_equal "Sent “#{things(:keyboard).name}” to #{printers(:brother_printer).name}.", flash[:notice]
  end

  test "print rejects disabled printer" do
    post print_thing_path(things(:keyboard)), params: { printer_id: printers(:receipt_printer).id }

    assert_redirected_to thing_path(things(:keyboard))
    assert_equal "Printer not found or disabled.", flash[:alert]
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
    assert_equal [ "Support", "Drivers" ], thing.custom_links.map(&:display_title)
    assert_equal [ 0, 1 ], thing.custom_links.map(&:position)
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
    assert_equal [ "Manual", "Firmware" ], router.custom_links.map(&:display_title)
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
        notes: "Moved to rack 3",
        links_attributes: {
          "0" => { id: thing_links(:router_asset).id, link_type: "asset", url: thing_links(:router_asset).url }
        }
      }
    }

    assert_redirected_to thing_path(things(:router))
    router = things(:router).reload
    assert_equal "Core Router", router.name
    assert_equal "Moved to rack 3", router.notes
  end

  test "updates standard link notes" do
    patch thing_path(things(:router)), params: {
      thing: {
        name: things(:router).name,
        links_attributes: {
          "0" => {
            id: thing_links(:router_asset).id,
            link_type: "asset",
            url: thing_links(:router_asset).url,
            note: "Updated rack note"
          }
        }
      }
    }

    assert_redirected_to thing_path(things(:router))
    assert_equal "Updated rack note", thing_links(:router_asset).reload.note
  end

  test "uploads ar anchor with note" do
    patch thing_path(things(:router)), params: {
      thing: {
        name: things(:router).name,
        ar_anchor: fixture_file_upload("ar_anchor.png", "image/png"),
        ar_anchor_note: "Marker on front panel"
      }
    }

    router = things(:router).reload
    assert_redirected_to thing_path(router)
    assert router.ar_anchor.attached?
    assert_equal "Marker on front panel", router.ar_anchor_note
  end

  test "purges ar anchor" do
    attach_ar_anchor(things(:router))

    assert things(:router).ar_anchor.attached?

    delete ar_anchor_thing_path(things(:router))

    assert_redirected_to thing_path(things(:router))
    assert_not things(:router).reload.ar_anchor.attached?
  end

  test "edit form includes standard link note fields" do
    get edit_thing_path(things(:router))

    assert_response :success
    assert_select "input[name*='[note]']"
    assert_select "input[name=?]", "thing[ar_anchor_note]"
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
