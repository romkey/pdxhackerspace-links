require "test_helper"

class Cups::ClientTest < ActiveSupport::TestCase
  setup do
    @success = Struct.new(:success?).new(true)
    @failure = Struct.new(:success?).new(false)
  end

  test "reachable when scheduler is running" do
    client = build_client do |_env, command, *_rest|
      case command
      when "lpstat" then [ "scheduler is running\n", "", @success ]
      else [ "", "", @failure ]
      end
    end

    assert client.reachable?
  end

  test "not reachable when scheduler is stopped" do
    client = build_client { |_env, _command, *_rest| [ "scheduler is not running\n", "", @success ] }

    assert_not client.reachable?
  end

  test "queue_names parses lpstat output" do
    output = <<~OUTPUT
      DYMO_LabelWriter accepting requests since Mon Jan 01 00:00:00 2024
      HP_LaserJet accepting requests since Mon Jan 01 00:00:00 2024
    OUTPUT

    client = build_client { |_env, _command, *_rest| [ output, "", @success ] }

    assert_equal %w[DYMO_LabelWriter HP_LaserJet], client.queue_names
  end

  test "print_file submits minimal landscape label options" do
    printer = printers(:brother_printer)
    file = Tempfile.new([ "label", ".pdf" ])
    file.write("test")
    file.close

    captured = []
    client = build_client do |*args|
      captured << args
      case args[1]
      when "lp" then [ "request id is Brother-1 (1 file(s))\n", "", @success ]
      when "lpstat" then [ "", "", @success ]
      else [ "", "", @failure ]
      end
    end

    assert client.print_file(
      file.path,
      printer: printer,
      title: "Test label",
      media: "Custom.62x94mm"
    )
    lp_args = captured.find { |args| args[1] == "lp" }
    assert_equal printer.cups_server, lp_args.first["CUPS_SERVER"]
    assert_equal "lp", lp_args[1]
    assert_includes lp_args, printer.cups_name
    assert_includes lp_args, "media=Custom.62x94mm"
    assert_includes lp_args, "PageSize=Custom.62x94mm"
    assert_includes lp_args, "print-scaling=none"
    assert_includes lp_args, "pdfAutoRotate=off"
    assert_includes lp_args, "job-sheets=none"
    assert_not_includes lp_args, "fit-to-page"
    assert_not_includes lp_args, "Cut=EveryPage"
    assert_not_includes lp_args, "orientation-requested=4"
  ensure
    file&.unlink
  end

  test "print_file raises when lpstat reports a filter failure" do
    printer = printers(:label_printer)
    file = Tempfile.new([ "label", ".pdf" ])
    file.write("test")
    file.close

    client = build_client do |*args|
      case args[1]
      when "lp" then [ "request id is DYMO-1 (1 file(s))\n", "", @success ]
      when "lpstat" then [ "Status: Filter failed\nReason: Page margins overlap\n", "", @success ]
      else [ "", "", @failure ]
      end
    end

    error = assert_raises(Cups::Client::Error) do
      client.print_file(file.path, printer: printer, media: "Custom.24x56mm")
    end
    assert_match(/Page margins overlap/i, error.message)
  ensure
    file&.unlink
  end

  test "resolve_media keeps fixed media unchanged" do
    client = build_client { |_env, _command, *_rest| [ "", "", @failure ] }

    assert_equal "4x6", client.resolve_media(printers(:shipping_printer))
    assert_equal "Custom.62x0mm", client.resolve_media(printers(:brother_printer))
    assert_equal "Custom.24x56mm", client.resolve_media(
      printers(:label_printer),
      page_width_mm: 56,
      page_height_mm: 24
    )
  end

  test "print_file omits fit-to-page for letter media" do
    printer = printers(:office_laser)
    file = Tempfile.new([ "sheet", ".pdf" ])
    file.write("test")
    file.close

    captured = nil
    client = build_client do |*args|
      captured = args
      [ "request id is HP-1 (1 file(s))\n", "", @success ]
    end

    client.print_file(file.path, printer: printer)
    assert_not_includes captured, "Cut=EveryPage"
  ensure
    file&.unlink
  end

  private

  def build_client(&runner)
    Cups::Client.new(server: "cups.example.com:631", runner: runner)
  end
end
