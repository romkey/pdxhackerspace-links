require "test_helper"

class Cups::ClientTest < ActiveSupport::TestCase
  setup do
    @success = Struct.new(:success?).new(true)
    @failure = Struct.new(:success?).new(false)
  end

  test "reachable when scheduler is running" do
    client = build_client do |_env, command, *_rest|
      case command
      when "lpstat" then ["scheduler is running\n", "", @success]
      else ["", "", @failure]
      end
    end

    assert client.reachable?
  end

  test "not reachable when scheduler is stopped" do
    client = build_client { |_env, _command, *_rest| ["scheduler is not running\n", "", @success] }

    assert_not client.reachable?
  end

  test "queue_names parses lpstat output" do
    output = <<~OUTPUT
      DYMO_LabelWriter accepting requests since Mon Jan 01 00:00:00 2024
      HP_LaserJet accepting requests since Mon Jan 01 00:00:00 2024
    OUTPUT

    client = build_client { |_env, _command, *_rest| [output, "", @success] }

    assert_equal %w[DYMO_LabelWriter HP_LaserJet], client.queue_names
  end

  test "print_file submits job with media option" do
    printer = printers(:label_printer)
    file = Tempfile.new(["label", ".pdf"])
    file.write("test")
    file.close

    captured = nil
    client = build_client do |*args|
      captured = args
      ["request id is DYMO-1 (1 file(s))\n", "", @success]
    end

    assert client.print_file(file.path, printer: printer, title: "Test label")
    assert_equal "cups.example.com:631", captured.first["CUPS_SERVER"]
    assert_equal "lp", captured[1]
    assert_includes captured, printer.cups_name
    assert_includes captured, "media=Custom.24x0mm"
  ensure
    file&.unlink
  end

  private

  def build_client(&runner)
    Cups::Client.new(server: "cups.example.com:631", runner: runner)
  end
end
