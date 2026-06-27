require "test_helper"

class Things::PrintLabelTest < ActiveSupport::TestCase
  test "submits generated label to cups with matching media" do
    printer = printers(:brother_printer)
    captured = []
    runner = lambda do |*_args|
      captured << _args
      case _args[1]
      when "lp" then [ "request id is Brother-1 (1 file(s))\n", "", Struct.new(:success?).new(true) ]
      when "lpstat" then [ "", "", Struct.new(:success?).new(true) ]
      else [ "", "", Struct.new(:success?).new(false) ]
      end
    end
    client = Cups::Client.new(server: printer.cups_server, runner: runner)

    assert Things::PrintLabel.call(
      thing: things(:keyboard),
      printer: printer,
      copies: 2,
      cups_client: client
    )

    lp_args = captured.find { |args| args[1] == "lp" }
    assert_equal "lp", lp_args[1]
    assert_includes lp_args, printer.cups_name
    assert_includes lp_args, "-n"
    assert_includes lp_args, "2"
    assert_includes lp_args, "media=Custom.62x94mm"
    assert_includes lp_args, "print-scaling=none"
  end

  test "24mm strip sends media that matches pdf dimensions" do
    printer = printers(:label_printer)
    label_pdf = Things::LabelPdf.new(thing: things(:router), printer: printer)
    captured = []
    runner = lambda do |*_args|
      captured << _args
      case _args[1]
      when "lp" then [ "request id is DYMO-1 (1 file(s))\n", "", Struct.new(:success?).new(true) ]
      when "lpstat" then [ "", "", Struct.new(:success?).new(true) ]
      else [ "", "", Struct.new(:success?).new(false) ]
      end
    end
    client = Cups::Client.new(server: printer.cups_server, runner: runner)

    Things::PrintLabel.call(thing: things(:router), printer: printer, cups_client: client)

    lp_args = captured.find { |args| args[1] == "lp" }
    assert_includes lp_args.join(" "), "media=#{label_pdf.cups_media}"
    assert_equal label_pdf.page_width_mm.round, label_pdf.cups_media[/Custom\.24x(\d+)mm/, 1].to_i
  ensure
    label_pdf&.cleanup!
  end

  test "rejects disabled printers" do
    assert_raises(ArgumentError) do
      Things::PrintLabel.call(thing: things(:keyboard), printer: printers(:receipt_printer))
    end
  end

  test "command printer runs print command with generated png" do
    printer = printers(:command_printer)
    captured = []
    runner = lambda do |path:, command:|
      captured << { path: path, command: command }
      assert File.exist?(path)
      assert_equal ".png", File.extname(path)
      assert_equal printer.print_command, command
      true
    end

    assert Things::PrintLabel.call(
      thing: things(:router),
      printer: printer,
      copies: 2,
      command_runner: runner
    )

    assert_equal 2, captured.size
  end
end
