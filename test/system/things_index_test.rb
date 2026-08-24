require "application_system_test_case"

class ThingsIndexTest < ApplicationSystemTestCase
  setup do
    sign_in_as(users(:local_admin))
  end

  test "mobile shows cards and desktop shows table" do
    page.driver.browser.manage.window.resize_to(390, 844)
    visit things_path

    assert_selector ".thing-card", minimum: 1
    assert_no_selector ".table-compact"

    page.driver.browser.manage.window.resize_to(1440, 900)
    visit things_path

    assert_selector ".table-compact"
    assert_no_selector ".thing-card"
  end

  test "filter offcanvas opens on mobile" do
    page.driver.browser.manage.window.resize_to(390, 844)
    visit things_path

    click_on "Filters"
    assert_selector "#things-filters-offcanvas.show", visible: :all
    assert_selector "#things-filters-offcanvas .filter-chip", minimum: 1
  end
end
