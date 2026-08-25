require "test_helper"

Capybara.register_driver :headless_chrome do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument("headless")
  options.add_argument("disable-gpu")
  options.add_argument("no-sandbox")
  options.add_argument("window-size=1400,1400")
  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :headless_chrome

  def sign_in_as(user)
    visit login_path
    if page.has_css?("summary", text: "Sign in locally", wait: 1)
      find("summary", text: "Sign in locally").click
    end
    fill_in "email", with: user.email
    fill_in "password", with: "secret"
    click_button "Sign in locally"
    assert_text "Things", wait: 5
  end
end
