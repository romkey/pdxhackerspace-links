require "application_system_test_case"

class ThingsShowTest < ApplicationSystemTestCase
  setup do
    @thing = things(:keyboard)
    @thing.link_for(:where).update!(url: "https://geowiki.example.com/locations/front-door", note: "Front door")
  end

  test "show layout places description beside photo with technical details below" do
    page.driver.browser.manage.window.resize_to(390, 844)
    visit thing_path(@thing)

    assert_selector "h1", text: @thing.name
    assert_selector ".where-panel", text: /Front door/
    assert_selector ".prose", text: @thing.description
    assert_selector ".h-section-label", text: /Technical details/i
    assert_no_selector "details"

    prose_position = page.evaluate_script <<~JS
      Array.from(document.querySelectorAll('.prose, .h-section-label')).indexOf(document.querySelector('.prose'))
    JS
    details_position = page.evaluate_script <<~JS
      Array.from(document.querySelectorAll('.prose, .h-section-label')).findIndex((el) => el.textContent.match(/Technical details/i))
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
