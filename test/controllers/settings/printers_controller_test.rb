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
    assert_select "td", text: "CUPS"
  end

  test "navbar includes settings link" do
    get settings_printers_path
    assert_select "a[href=?]", settings_root_path, text: "Settings"
  end

  test "creates remote brother label printer" do
    assert_difference -> { Printer.count }, 1 do
      post settings_printers_path, params: {
        printer: {
          name: "Workshop Brother",
          cups_server: "192.168.1.50:631",
          cups_name: "Brother_QL",
          page_size: "label_brother_62mm",
          description: "Workshop bench",
          enabled: true
        }
      }
    end

    printer = Printer.order(:created_at).last
    assert_redirected_to settings_printer_path(printer)
    assert_equal "192.168.1.50:631", printer.cups_server
    assert_equal "Custom.62x0mm", printer.cups_media
  end

  test "creates letter printer with avery template" do
    post settings_printers_path, params: {
      printer: {
        name: "Mailroom",
        cups_server: "192.168.1.10:631",
        cups_name: "HP_Office",
        page_size: "letter",
        avery_template: "avery_5163",
        enabled: true
      }
    }

    printer = Printer.order(:created_at).last
    assert_equal "avery_5163", printer.avery_template
    assert_equal "Avery 5163", printer.avery_template_label
  end

  test "creates command printer" do
    assert_difference -> { Printer.count }, 1 do
      post settings_printers_path, params: {
        printer: {
          name: "Local script",
          printer_type: "command",
          label_height_mm: 24,
          print_command: "/usr/local/bin/print FILENAME",
          enabled: true
        }
      }
    end

    printer = Printer.order(:created_at).last
    assert_redirected_to settings_printer_path(printer)
    assert printer.command?
    assert_equal 24, printer.label_height_mm
  end

  test "updates printer" do
    patch settings_printer_path(printers(:receipt_printer)), params: {
      printer: {
        name: printers(:receipt_printer).name,
        cups_server: printers(:receipt_printer).cups_server,
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
    assert_select "option", text: "Avery 5160"
  end

  test "new form includes refresh queues button" do
    get new_settings_printer_path

    assert_response :success
    assert_select "button[data-action=?]", "click->cups-queues#refreshQueues", text: /Refresh queues/
  end

  test "cups_queues returns json for a valid server address" do
    get cups_queues_settings_printers_path, params: { server: "localhost:631" }, as: :json

    assert_response :success
    body = JSON.parse(response.body)
    assert_includes [ true, false ], body["reachable"]
    assert_kind_of Array, body["queues"]
  end

  test "cups_queues rejects invalid server address" do
    get cups_queues_settings_printers_path, params: { server: "not valid" }, as: :json
    assert_response :bad_request
  end

  test "requires authentication" do
    delete logout_path
    get settings_printers_path
    assert_redirected_to login_path
  end

  test "test print sends label and redirects with notice" do
    printer = printers(:brother_printer)

    with_fake_cups_client(server: printer.cups_server) do
      post test_print_settings_printer_path(printer)
    end

    assert_redirected_to settings_printer_path(printer)
    assert_equal "Sent test label to #{printer.name}.", flash[:notice]
  end

  test "test print surfaces cups errors" do
    printer = printers(:brother_printer)

    with_fake_cups_client(server: printer.cups_server, fail_print: true) do
      post test_print_settings_printer_path(printer)
    end

    assert_redirected_to settings_printer_path(printer)
    assert_equal "lp: unable to connect", flash[:alert]
  end

  test "show page includes test print button" do
    get settings_printer_path(printers(:brother_printer))

    assert_response :success
    assert_select "button", text: "Test print"
  end

  test "command printer test print redirects with notice" do
    printer = printers(:command_printer)
    called = false
    original = Printers::PrintTestLabel.method(:call)
    Printers::PrintTestLabel.define_singleton_method(:call) do |**_kwargs|
      called = true
      true
    end

    post test_print_settings_printer_path(printer)

    assert called
    assert_redirected_to settings_printer_path(printer)
    assert_equal "Sent test label to #{printer.name}.", flash[:notice]
  ensure
    Printers::PrintTestLabel.define_singleton_method(:call, original)
  end
end
