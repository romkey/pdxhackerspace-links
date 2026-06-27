require "test_helper"

class AppHostLabelPreviewRegressionTest < ActionDispatch::IntegrationTest
  REGRESSION_HOST = "https://links.regression.test"

  setup do
    sign_in_as(users(:local_admin))
  end

  test "label preview page and assets reflect current APP_HOST" do
    with_app_host(REGRESSION_HOST) do
      thing = things(:router)

      get label_preview_thing_path(thing, printer_id: printers(:label_printer).id)

      assert_response :success
      assert_select "code", text: "#{REGRESSION_HOST}/things/#{thing.id}?utm_source=qrcode"

      get label_preview_thing_path(thing, printer_id: printers(:label_printer).id, format: :pdf)

      assert_response :success
      assert_equal "no-store", response.headers["Cache-Control"]

      get label_preview_thing_path(thing, printer_id: printers(:command_printer).id, format: :png)

      assert_response :success
      assert_equal "no-store", response.headers["Cache-Control"]
    end
  end
end
