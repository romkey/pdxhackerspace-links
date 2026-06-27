require "open3"
require "shellwords"

module Printers
  class RunPrintCommand
    PRECUT_FLAG = "--precut".freeze

    def self.call(path:, command:, precut_before: false, runner: nil)
      new(path: path, command: command, precut_before: precut_before, runner: runner).call
    end

    def initialize(path:, command:, precut_before: false, runner: nil)
      @path = path
      @command = command
      @precut_before = precut_before
      @runner = runner || method(:default_runner)
    end

    def call
      raise CommandError, "Print command is blank" if command.blank?

      shell_command = build_shell_command
      stdout, stderr, status = runner.call(shell_command)

      return true if status.success?

      message = [ stderr, stdout ].map(&:strip).reject(&:blank?).join(": ")
      raise CommandError, message.presence || "Print command failed"
    end

    def build_shell_command
      cmd = command.gsub(Printer::PRINT_COMMAND_FILENAME, Shellwords.escape(path))
      return cmd unless precut_before?
      return cmd if cmd.include?(PRECUT_FLAG)
      return cmd unless cmd.match?(/\bptouch\b/)

      cmd.sub(/\bprint\b/, "print #{PRECUT_FLAG}")
    end

    private

    attr_reader :path, :command, :precut_before, :runner

    alias precut_before? precut_before

    def default_runner(shell_command)
      Open3.capture3("bash", "-c", shell_command)
    end
  end
end
