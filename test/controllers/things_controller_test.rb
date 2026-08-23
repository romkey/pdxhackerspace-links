require "test_helper"

class ThingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:local_admin))
  end

  test "index lists things with hostname and ip address" do
    get things_path
    assert_response :success
    assert_select "td", text: things(:keyboard).name
    assert_select "code", text: things(:router).ip_address
    assert_select "code", text: things(:keyboard).key, count: 0
    assert_select "nav input[type=search][name=q]"
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
    assert_select "a[href*=?]", "label_preview", count: 0
    assert_select "button", text: "Duplicate"
  end

  test "show resolves thing by slug" do
    get thing_path("front-door-keyboard")
    assert_response :success
    assert_select "h1", things(:keyboard).name
  end

  test "show still resolves thing by id when slug is not set" do
    get thing_path(things(:router).id)
    assert_response :success
    assert_select "h1", things(:router).name
  end

  test "show resolves thing by key at short path" do
    get short_thing_path(things(:keyboard).key)
    assert_response :success
    assert_select "h1", things(:keyboard).name
  end

  test "abbreviated short url redirects to full thing url with utm_source" do
    thing = things(:keyboard)

    with_app_host("https://links.example.org") do
      get "#{short_thing_path(thing.key)}?q"

      assert_response :found
      assert_equal "https://links.example.org/things/#{thing.slug}?utm_source=qrcode", response.location
    end
  end

  test "abbreviated short url with legacy utm_source still redirects to full thing url" do
    thing = things(:keyboard)

    with_app_host("https://links.example.org") do
      get short_thing_path(thing.key, utm_source: "qrcode")

      assert_response :found
      assert_equal "https://links.example.org/things/#{thing.slug}?utm_source=qrcode", response.location
    end
  end

  test "abbreviated short url tracks scan after redirect to full thing url" do
    thing = things(:keyboard)
    thing.links.find_by(link_type: :slack).destroy!

    with_app_host("https://links.example.org") do
      assert_difference -> { thing.reload.qr_scan_count }, 1 do
        get "#{short_thing_path(thing.key)}?q"
        follow_redirect!
        follow_redirect!
      end

      assert_response :success
    end
  end

  test "show displays key" do
    get thing_path(things(:keyboard))
    assert_response :success
    assert_select "code", text: things(:keyboard).key
  end

  test "show displays slug when set" do
    get thing_path(things(:keyboard))
    assert_response :success
    assert_select "code", text: things(:keyboard).slug
  end

  test "creates thing with slug" do
    assert_difference -> { Thing.count }, 1 do
      post things_path, params: {
        thing: {
          name: "Door Lock",
          slug: "door-lock",
          links_attributes: {
            "0" => { link_type: "asset", url: "" },
            "1" => { link_type: "wiki", url: "" },
            "2" => { link_type: "slack", url: "" },
            "3" => { link_type: "where", url: "" },
            "4" => { link_type: "ar", url: "" }
          }
        }
      }
    end

    thing = Thing.order(:created_at).last
    assert_redirected_to thing_path("door-lock")
    assert_equal "door-lock", thing.slug
  end

  test "update redirects to slug path when slug is set" do
    patch thing_path(things(:router)), params: {
      thing: {
        name: things(:router).name,
        slug: "core-router"
      }
    }

    assert_redirected_to thing_path("core-router")
    assert_equal "core-router", things(:router).reload.slug
  end

  test "show displays ble beacon uuid when set" do
    get thing_path(things(:router))
    assert_response :success
    assert_select "code", text: things(:router).ble_beacon_uuid
  end

  test "by_beacon redirects to thing show page" do
    things(:router).update!(slug: "core-router")
    get by_beacon_things_path(ble_beacon_uuid: things(:router).ble_beacon_uuid)
    assert_redirected_to thing_path("core-router")
    follow_redirect!
    assert_response :success
    assert_select "h1", things(:router).name
  end

  test "by_beacon accepts uppercase uuid" do
    get by_beacon_things_path(ble_beacon_uuid: things(:router).ble_beacon_uuid.upcase)
    assert_redirected_to thing_path(things(:router))
  end

  test "by_beacon returns not found for unknown uuid" do
    get by_beacon_things_path(ble_beacon_uuid: "00000000-0000-0000-0000-000000000000")
    assert_response :not_found
  end

  test "by_beacon requires authentication for private thing" do
    delete logout_path

    get by_beacon_things_path(ble_beacon_uuid: things(:router).ble_beacon_uuid)
    assert_redirected_to login_path
  end

  test "by_beacon allows public thing without authentication" do
    delete logout_path
    things(:keyboard).update!(ble_beacon_uuid: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")

    with_network_whitelist(nil) do
      get by_beacon_things_path(ble_beacon_uuid: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")
      assert_redirected_to thing_path(things(:keyboard))
    end
  end

  test "show with utm_source qrcode and single link shows redirect countdown" do
    thing = things(:keyboard)
    thing.links.find_by(link_type: :slack).destroy!

    assert_difference -> { thing.reload.qr_scan_count }, 1 do
      get thing_path(thing, utm_source: "qrcode")
    end

    assert_redirected_to thing_path(thing)
    follow_redirect!

    assert_response :success
    assert_select "[data-controller='redirect-countdown']"
    assert_select "[data-redirect-countdown-url-value=?]", thing_links(:keyboard_wiki).url
    assert_select "span[data-redirect-countdown-target='countdown']", text: "5"
  end

  test "show with utm_source nfc and single link shows redirect countdown" do
    thing = things(:keyboard)
    thing.links.find_by(link_type: :slack).destroy!

    assert_difference -> { thing.reload.nfc_scan_count }, 1 do
      get thing_path(thing, utm_source: "nfc")
    end

    assert_redirected_to thing_path(thing)
    follow_redirect!

    assert_response :success
    assert_select "[data-controller='redirect-countdown']"
  end

  test "show with utm_source qrcode and multiple links does not redirect countdown" do
    thing = things(:keyboard)

    assert_difference -> { thing.reload.qr_scan_count }, 1 do
      get thing_path(thing, utm_source: "qrcode")
    end

    assert_redirected_to thing_path(thing)
    follow_redirect!

    assert_response :success
    assert_select "[data-controller='redirect-countdown']", count: 0
  end

  test "show with unknown utm_source does not increment scans" do
    thing = things(:keyboard)
    thing.links.find_by(link_type: :slack).destroy!

    assert_no_difference -> { thing.reload.qr_scan_count } do
      assert_no_difference -> { thing.nfc_scan_count } do
        get thing_path(thing, utm_source: "email")
      end
    end

    assert_response :success
    assert_select "[data-controller='redirect-countdown']", count: 0
  end

  test "show increments visit count" do
    thing = things(:router)
    thing.update!(visit_count: 0)

    assert_difference -> { thing.reload.visit_count }, 1 do
      get thing_path(thing)
    end
  end

  test "show displays scan visit counts" do
    things(:router).update!(qr_scan_count: 4, nfc_scan_count: 2, visit_count: 10)

    get thing_path(things(:router))

    assert_response :success
    assert_select ".h-section-label", text: "Scan visits"
    assert_match(/4.*QR.*2.*NFC.*11.*visits/m, response.body)
  end

  test "show displays standard link notes" do
    get thing_path(things(:router))

    assert_response :success
    assert_select ".list-group-item", text: /Asset/
    assert_select ".list-group-item", text: /Front rack label/
  end

  test "show displays ar marker when attached" do
    attach_ar_anchor(things(:router))
    things(:router).update!(ar_anchor_note: "Scan from the front")

    get thing_path(things(:router))

    assert_response :success
    assert_select ".h-section-label", text: "AR Marker"
    assert_select "img[src]"
    assert_select ".text-12", text: "Scan from the front"
  end

  test "label preview shows scaled pdf and print action" do
    get label_preview_thing_path(things(:router), printer_id: printers(:label_printer).id)

    assert_response :success
    assert_select "h1", "Standard label preview"
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

  test "show includes print label button" do
    get thing_path(things(:router))

    assert_response :success
    assert_select "button", text: "Print label"
  end

  test "show omits cable tag layout when thing has no network lines" do
    get thing_path(things(:keyboard))

    assert_response :success
    assert_select "button", text: "Print label"
  end

  test "show includes print label when thing has hostname only" do
    things(:keyboard).update!(hostname: "switch.local")

    get thing_path(things(:keyboard))

    assert_response :success
    assert_select "button", text: "Print label"
  end

  test "portrait label preview renders without margin controls" do
    get label_preview_thing_path(things(:keyboard), printer_id: printers(:office_laser).id)

    assert_response :success
    assert_select "input#label-left-margin", count: 0
    assert_select "[data-controller='label-preview']"
  end

  test "label preview accepts margin overrides" do
    get label_preview_thing_path(
      things(:router),
      printer_id: printers(:label_printer).id,
      layout: :cable_tag,
      left_margin_mm: 2,
      right_margin_mm: 5,
      cable_tag_gap_mm: 12
    )

    assert_response :success
    assert_select "input#label-left-margin" do |inputs|
      assert_in_delta 2, inputs.first["value"].to_f, 0.01
    end
    assert_select "input#label-right-margin" do |inputs|
      assert_in_delta 5, inputs.first["value"].to_f, 0.01
    end
    assert_select "input#label-middle-gap" do |inputs|
      assert_in_delta 12, inputs.first["value"].to_f, 0.01
    end
    assert_select "[data-controller='label-preview']"
  end

  test "cable tag preview and print use wrap layout" do
    get label_preview_thing_path(things(:router), printer_id: printers(:label_printer).id, layout: :cable_tag)

    assert_response :success
    assert_select "h1", "Cable tag preview"
    assert_select "iframe[src=?]",
                  label_preview_thing_path(things(:router), printer_id: printers(:label_printer).id, format: :pdf, layout: :cable_tag)

    with_fake_cups_client do
      post print_thing_path(things(:router)), params: { printer_id: printers(:label_printer).id, layout: :cable_tag }
    end

    assert_redirected_to thing_path(things(:router))
    assert_match(/cable tag/i, flash[:notice])
  end

  test "index includes scan counts for admins" do
    things(:router).update!(qr_scan_count: 4, nfc_scan_count: 2, visit_count: 10)

    get things_path

    assert_response :success
    assert_select "th", text: /Views/
    assert_select "th", text: /NFC/
    assert_select "th", text: /QR/
    assert_select "td.num", text: "10"
    assert_select "td.num", text: "4"
    assert_select "td.num", text: "2"
  end

  test "index supports sortable headers" do
    get things_path, params: { sort: "ip_address", direction: "desc" }

    assert_response :success
    assert_select "a[href=?]", things_path(sort: "ip_address", direction: "asc", page: 1)
    assert_equal things(:router).name, css_select("tbody tr td.fw-medium").first.text
  end

  test "index supports stackable filters" do
    get things_path, params: { filter: { links: "yes", ip_address: "yes" } }

    assert_response :success
    assert_select "td", text: things(:router).name
    assert_select "td", text: things(:keyboard).name, count: 0
    assert_select "a.filter-chip.active", count: 2
    assert_select "a.filter-chip.active", text: /Links/
    assert_select "a.filter-chip.active", text: /IP address/
    assert_select "a.filter-chip.active i.bi-check-lg", count: 2
  end

  test "index filter chips cycle through any, has, and none" do
    get things_path
    assert_response :success
    assert_select "a.filter-chip[href=?]",
                  things_path(sort: "name", direction: "asc", filter: { links: "yes" })

    get things_path, params: { filter: { links: "yes" } }
    assert_response :success
    assert_select "a.filter-chip.active[href=?]",
                  things_path(sort: "name", direction: "asc", filter: { links: "no" })

    get things_path, params: { filter: { links: "no" } }
    assert_response :success
    assert_select "a.filter-chip.active[href=?]", things_path(sort: "name", direction: "asc")
  end

  test "index marks excluded filters with a struck through label" do
    get things_path, params: { filter: { photos: "no" } }

    assert_response :success
    assert_select "a.filter-chip.active i.bi-slash-lg"
    assert_select "a.filter-chip.active .text-decoration-line-through", text: "Photos"
  end

  test "index renders one chip per filter with no state labels" do
    get things_path

    expected_chips = ThingsHelper::THINGS_INDEX_FILTER_GROUPS.size + Integrations::Registry.filter_keys.size

    assert_response :success
    assert_select "a.filter-chip", count: expected_chips
    assert_select "a.filter-chip.active", count: 0
    assert_select "a.filter-chip", text: /Any/, count: 0
  end

  test "index shows clear filters link when filters are active" do
    get things_path, params: { filter: { photos: "no" } }

    assert_response :success
    assert_select "a", text: "Clear filters"
  end

  test "index clears filters while preserving search" do
    get things_path, params: { q: "router", filter: { links: "yes" } }

    assert_response :success
    assert_select "a[href=?]", things_path(q: "router", sort: "name", direction: "asc")
  end

  test "index paginates things" do
    existing = Thing.count
    (Pagy::OPTIONS[:limit] - existing + 1).times do |index|
      Thing.create!(name: "Thing #{index}")
    end

    get things_path

    assert_response :success
    assert_select ".pagination"
  end

  test "index includes inline row actions when printers are enabled" do
    get things_path
    assert_response :success
    assert_select "a[href=?]", edit_thing_path(things(:keyboard))
    assert_select "button", text: "Duplicate"
    assert_select "button", text: "Delete"
    assert_select "button", text: "Print"
    assert_select "button[aria-label='More actions']"
  end

  test "index print buttons target the shared print dialog" do
    get things_path

    assert_response :success
    assert_select "button[data-bs-target='#print-label-dialog'][data-action*='print-dialog#open']", minimum: 1
  end

  test "show print button targets the shared print dialog" do
    get thing_path(things(:keyboard))

    assert_response :success
    assert_select "button[data-bs-target='#print-label-dialog'][data-action*='print-dialog#open']"
  end

  test "index includes bulk label preview url for print dialog" do
    get things_path

    assert_response :success
    doc = Nokogiri::HTML(response.body)
    container = doc.at_css('[data-controller*="print-dialog"]')
    assert_equal bulk_label_preview_things_path, container["data-print-dialog-bulk-preview-url-value"]
  end

  test "index encodes stimulus data attributes for bulk print" do
    get things_path

    assert_response :success
    doc = Nokogiri::HTML(response.body)
    container = doc.at_css('[data-controller*="thing-selection"]')
    assert container

    filter_params = JSON.parse(container["data-thing-selection-filter-params-value"])
    assert filter_params.key?("sort")

    printers = JSON.parse(container["data-print-dialog-printers-value"])
    assert_kind_of Array, printers
    assert printers.any?
  end

  test "show encodes stimulus data attributes for print dialog" do
    get thing_path(things(:keyboard))

    assert_response :success
    doc = Nokogiri::HTML(response.body)
    container = doc.at_css('[data-controller="print-dialog"]')
    assert container

    printers = JSON.parse(container["data-print-dialog-printers-value"])
    assert_kind_of Array, printers
    assert printers.any?
  end

  test "print marks thing labelled when requested" do
    thing = things(:keyboard)
    assert_not thing.labelled?

    with_fake_cups_client do
      post print_thing_path(thing), params: { printer_id: printers(:brother_printer).id, mark_labelled: "1" }
    end

    assert thing.reload.labelled?
  end

  test "update_labelled toggles labelled state" do
    thing = things(:keyboard)

    patch labelled_thing_path(thing), params: { labelled: "1" }
    assert_redirected_to thing_path(thing)
    assert thing.reload.labelled?

    patch labelled_thing_path(thing), params: { labelled: "0" }
    assert_not thing.reload.labelled?
  end

  test "bulk label preview shows each selected thing" do
    get bulk_label_preview_things_path, params: {
      thing_ids: [ things(:keyboard).id, things(:router).id ],
      printer_id: printers(:label_printer).id,
      layout: "standard"
    }

    assert_response :success
    assert_select "h1", "Label preview"
    assert_select ".bulk-label-preview-row", count: 2
    assert_select "iframe[title=?]", "Label preview for #{things(:keyboard).name}"
    assert_select "iframe[title=?]", "Label preview for #{things(:router).name}"
  end

  test "bulk label preview skips things without network lines for cable tags" do
    get bulk_label_preview_things_path, params: {
      thing_ids: [ things(:keyboard).id, things(:router).id ],
      printer_id: printers(:label_printer).id,
      layout: "cable_tag"
    }

    assert_response :success
    assert_select ".bulk-label-preview-row", count: 1
    assert_select "iframe[title=?]", "Label preview for #{things(:router).name}"
    assert_match(/skipped without IP or hostname/, response.body)
  end

  test "bulk print queues job for selected things" do
    assert_enqueued_with(job: Things::BulkPrintJob) do
      post bulk_print_things_path, params: {
        thing_ids: [ things(:keyboard).id, things(:router).id ],
        printer_id: printers(:brother_printer).id,
        layout: "standard",
        mark_labelled: "1"
      }
    end

    assert_redirected_to things_path
    assert_match(/Queued 2 labels/, flash[:notice])
  end

  test "bulk print with select all uses filtered scope" do
    things(:router).mark_labelled!
    Thing.create!(name: "Unlabelled extra")

    assert_enqueued_with(job: Things::BulkPrintJob) do
      post bulk_print_things_path, params: {
        select_all: "1",
        filter: { labelled: "yes" },
        printer_id: printers(:brother_printer).id,
        layout: "standard"
      }
    end

    assert_redirected_to things_path
    assert_match(/Queued 1 label/, flash[:notice])
  end

  test "bulk print skips things without network lines for cable tags" do
    assert_enqueued_with(job: Things::BulkPrintJob) do
      post bulk_print_things_path, params: {
        thing_ids: [ things(:keyboard).id, things(:router).id ],
        printer_id: printers(:label_printer).id,
        layout: "cable_tag"
      }
    end

    assert_match(/Skipped 1/, flash[:notice])
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
    assert_equal "Sent standard label for “#{things(:keyboard).name}” to #{printers(:brother_printer).name}.", flash[:notice]
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
            "4" => { link_type: "ar", url: "" },
            "5" => { link_type: "custom", title: "Support", url: "https://example.com/support", position: 0 }
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
          "4" => { link_type: "ar", url: "" },
          "5" => { link_type: "custom", title: "Support", url: "https://example.com/support" },
          "6" => { link_type: "custom", title: "Drivers", url: "https://example.com/drivers" }
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
        ble_beacon_uuid: "12345678-1234-1234-1234-123456789abc",
        links_attributes: {
          "0" => { id: thing_links(:router_asset).id, link_type: "asset", url: thing_links(:router_asset).url }
        }
      }
    }

    assert_redirected_to thing_path(things(:router))
    router = things(:router).reload
    assert_equal "Core Router", router.name
    assert_equal "Moved to rack 3", router.notes
    assert_equal "12345678-1234-1234-1234-123456789abc", router.ble_beacon_uuid
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

  test "uploads ar marker with note" do
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

  test "purges ar marker" do
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

  test "search returns matching things as json" do
    get search_things_path, params: { q: "keyboard" }, as: :json

    assert_response :success
    payload = JSON.parse(response.body)
    assert_equal 1, payload.size
    assert_equal things(:keyboard).id, payload.first["id"]
    assert_equal "Keyboard", payload.first["name"]
  end

  test "search excludes current thing" do
    get search_things_path, params: { q: "keyboard", exclude_id: things(:keyboard).id }, as: :json

    assert_response :success
    payload = JSON.parse(response.body)
    assert_empty payload
  end

  test "search requires authentication" do
    delete logout_path

    get search_things_path, params: { q: "keyboard" }, as: :json

    assert_redirected_to login_path
  end

  test "show displays related things for signed in users" do
    get thing_path(things(:keyboard))

    assert_response :success
    assert_select ".h-section-label", text: "Related things"
    assert_select "a[href=?]", thing_path(things(:router)), text: /Router/
  end

  test "public guest does not see related things" do
    delete logout_path

    with_network_whitelist(nil) do
      get thing_path(things(:keyboard))
      assert_response :success
      assert_select ".h-section-label", text: "Related things", count: 0
      assert_select "a[href=?]", thing_path(things(:router)), count: 0
    end
  end

  test "edit form includes related things section" do
    get edit_thing_path(things(:keyboard))

    assert_response :success
    assert_select "[data-controller='related-things']"
    assert_select "input[name=?]", "thing[thing_relationships_attributes][0][note]"
  end

  test "creates thing with related thing" do
    dongle = Thing.create!(name: "Dongle")

    assert_difference -> { Thing.count }, 1 do
      post things_path, params: {
        thing: {
          name: "Mouse",
          thing_relationships_attributes: [
            { related_thing_id: dongle.id, note: "USB receiver" }
          ]
        }
      }
    end

    mouse = Thing.order(:id).last
    assert_redirected_to thing_path(mouse)
    assert mouse.related_things.include?(dongle)
    assert dongle.related_things.include?(mouse)
  end

  test "updates thing relationships" do
    keyboard = things(:keyboard)
    dongle = Thing.create!(name: "Dongle")

    patch thing_path(keyboard), params: {
      thing: {
        name: keyboard.name,
        thing_relationships_attributes: [
          { related_thing_id: dongle.id, note: "Spare dongle" }
        ]
      }
    }

    assert_redirected_to thing_path(keyboard)
    assert keyboard.reload.related_things.include?(dongle)
  end
end
