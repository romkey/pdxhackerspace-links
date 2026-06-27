require "test_helper"

class Printers::RunPrintCommandTest < ActiveSupport::TestCase
  test "substitutes filename and runs command" do
    path = "/tmp/label.png"
    command = "cat FILENAME"
    runner = lambda do |shell_command|
      assert_equal "cat #{Shellwords.escape(path)}", shell_command
      [ "ok", "", Struct.new(:success?).new(true) ]
    end

    assert Printers::RunPrintCommand.call(path: path, command: command, runner: runner)
  end

  test "raises command error when command fails" do
    runner = lambda do |_shell_command|
      [ "", "script failed", Struct.new(:success?).new(false) ]
    end

    error = assert_raises(Printers::CommandError) do
      Printers::RunPrintCommand.call(path: "/tmp/label.png", command: "false FILENAME", runner: runner)
    end

    assert_equal "script failed", error.message
  end

  test "requires print command" do
    assert_raises(Printers::CommandError) do
      Printers::RunPrintCommand.call(path: "/tmp/label.png", command: "")
    end
  end

  test "inserts precut for ptouch commands when enabled" do
    runner = lambda do |shell_command|
      assert_equal "/usr/bin/ptouch print --precut -i #{Shellwords.escape('/tmp/label.png')} --model X", shell_command
      [ "", "", Struct.new(:success?).new(true) ]
    end

    assert Printers::RunPrintCommand.call(
      path: "/tmp/label.png",
      command: "/usr/bin/ptouch print -i FILENAME --model X",
      precut_before: true,
      runner: runner
    )
  end

  test "does not duplicate precut flag when already present" do
    command = Printers::RunPrintCommand.new(
      path: "/tmp/label.png",
      command: "/usr/bin/ptouch print --precut -i FILENAME",
      precut_before: true
    )

    assert_equal "/usr/bin/ptouch print --precut -i #{Shellwords.escape('/tmp/label.png')}",
                 command.build_shell_command
  end

  test "skips precut for non-ptouch commands" do
    command = Printers::RunPrintCommand.new(
      path: "/tmp/label.png",
      command: "/usr/local/bin/print-label FILENAME",
      precut_before: true
    )

    assert_equal "/usr/local/bin/print-label #{Shellwords.escape('/tmp/label.png')}",
                 command.build_shell_command
  end
end
