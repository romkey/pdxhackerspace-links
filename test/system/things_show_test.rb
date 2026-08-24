require "application_system_test_case"

class ThingsShowTest < ApplicationSystemTestCase
  setup do
    @thing = things(:keyboard)
    @thing.link_for(:where).update!(url: "https://geowiki.example.com/locations/front-door", note: "Front door")
  end

  test "scanner layout shows hero, where, and description above technical details on mobile" do
    page.driver.browser.manage.window.resize_to(390, 844)
    visit thing_path(@thing)

    assert_selector "h1", text: @thing.name
    assert_selector ".where-panel", text: /Front door/
    assert_selector ".prose", text: @thing.description
    assert_selector "details summary", text: /Details/

    assert_selector "details:not([open])"

    prose_position = page.evaluate_script <<~JS
      Array.from(document.querySelectorAll('.where-panel, .prose, details')).indexOf(document.querySelector('.prose'))
    JS
    details_position = page.evaluate_script <<~JS
      Array.from(document.querySelectorAll('.where-panel, .prose, details')).indexOf(document.querySelector('details'))
    JS
    assert prose_position < details_position
  end

  test "non-admin scan view hides scan counters and admin chrome" do
    page.driver.browser.manage.window.resize_to(390, 844)
    visit thing_path(@thing)

    assert_no_text "Scan visits"
    assert_no_button "Edit"
    assert_no_button "Print label"
  end
end
