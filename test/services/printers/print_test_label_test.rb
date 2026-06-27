require "test_helper"

class Printers::PrintTestLabelTest < ActiveSupport::TestCase
  test "submits test label to cups without requiring enabled printer" do
    printer = printers(:receipt_printer)
    captured = []
    runner = lambda do |*_args|
      captured << _args
      case _args[1]
      when "lp" then [ "request id is Epson-1 (1 file(s))\n", "", Struct.new(:success?).new(true) ]
      when "lpstat" then [ "", "", Struct.new(:success?).new(true) ]
      else [ "", "", Struct.new(:success?).new(false) ]
      end
    end
    client = Cups::Client.new(server: printer.cups_server, runner: runner)

    assert Printers::PrintTestLabel.call(printer: printer, cups_client: client)

    lp_args = captured.find { |args| args[1] == "lp" }
    assert_includes lp_args, printer.cups_name
    assert_includes lp_args.join(" "), "Test label"
    assert_includes lp_args, "print-scaling=none"
  end

  test "24mm strip test label uses sample owner and ip rows" do
    printer = printers(:label_printer)
    label = Printers::TestLabel.for_printer(printer)

    assert_equal "Test label Links", label.label_title_line
    assert_equal "192.168.1.1", label.label_ip_line
  end

  test "command printer test label uses strip layout content" do
    printer = printers(:command_printer)
    label = Printers::TestLabel.for_printer(printer)

    assert_equal "Test label Links", label.label_title_line
    assert_equal "192.168.1.1", label.label_ip_line
  end

  test "command printer submits png via print command" do
    printer = printers(:command_printer)
    captured = []
    runner = lambda do |path:, command:|
      captured << { path: path, command: command }
      assert File.exist?(path)
      assert_equal ".png", File.extname(path)
      assert_equal printer.print_command, command
      true
    end

    assert Printers::PrintTestLabel.call(printer: printer, command_runner: runner)
  end
end
