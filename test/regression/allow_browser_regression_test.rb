require "test_helper"

class AllowBrowserRegressionTest < ActionDispatch::IntegrationTest
  OLD_SAFARI_UA = "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1"

  setup do
    sign_in_as(users(:local_admin))
  end

  test "thing show does not block older safari user agents" do
    get thing_path(things(:router)), headers: { "HTTP_USER_AGENT" => OLD_SAFARI_UA }

    assert_not_equal 406, response.status
    assert_response :success
  end

  test "label preview pdf does not block older safari user agents" do
    get label_preview_thing_path(things(:router), printer_id: printers(:label_printer).id, format: :pdf),
        headers: { "HTTP_USER_AGENT" => OLD_SAFARI_UA }

    assert_not_equal 406, response.status
    assert_response :success
    assert_equal "application/pdf", response.media_type
  end
end
