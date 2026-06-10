require "test_helper"

class Settings::PrintersControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:local_admin))
    SiteSetting.instance.update!(cups_server: "cups.example.com:631")
  end

  test "index lists printers" do
    get settings_printers_path
    assert_response :success
    assert_select "td", text: printers(:label_printer).name
  end

  test "navbar includes site settings link" do
    get settings_printers_path
    assert_select "a[href=?]", settings_root_path, text: "Site settings"
  end

  test "creates printer" do
    assert_difference -> { Printer.count }, 1 do
      post settings_printers_path, params: {
        printer: {
          name: "Workshop label",
          cups_name: "Brother_QL",
          page_size: "label_strip_24mm",
          description: "Workshop bench",
          enabled: true
        }
      }
    end

    printer = Printer.order(:created_at).last
    assert_redirected_to settings_printer_path(printer)
    assert_equal "Workshop label", printer.name
    assert_equal "Custom.24x0mm", printer.cups_media
  end

  test "updates printer" do
    patch settings_printer_path(printers(:receipt_printer)), params: {
      printer: {
        name: printers(:receipt_printer).name,
        cups_name: printers(:receipt_printer).cups_name,
        page_size: "receipt_80mm",
        enabled: true
      }
    }

    assert_redirected_to settings_printer_path(printers(:receipt_printer))
    assert printers(:receipt_printer).reload.enabled?
  end

  test "destroys printer" do
    assert_difference -> { Printer.count }, -1 do
      delete settings_printer_path(printers(:office_laser))
    end

    assert_redirected_to settings_printers_path
  end

  test "new form lists page size options" do
    get new_settings_printer_path

    assert_response :success
    assert_select "input[type=radio][name=?]", "printer[page_size]", count: Printer::PAGE_SIZES.size
  end

  test "requires authentication" do
    delete logout_path
    get settings_printers_path
    assert_redirected_to login_path
  end
end
