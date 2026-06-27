require "open3"
require "shellwords"

module Printers
  class RunPrintCommand
    def self.call(path:, command:, runner: nil)
      new(path: path, command: command, runner: runner).call
    end

    def initialize(path:, command:, runner: nil)
      @path = path
      @command = command
      @runner = runner || method(:default_runner)
    end

    def call
      raise CommandError, "Print command is blank" if command.blank?

      shell_command = command.gsub(Printer::PRINT_COMMAND_FILENAME, Shellwords.escape(path))
      stdout, stderr, status = runner.call(shell_command)

      return true if status.success?

      message = [ stderr, stdout ].map(&:strip).reject(&:blank?).join(": ")
      raise CommandError, message.presence || "Print command failed"
    end

    private

    attr_reader :path, :command, :runner

    def default_runner(shell_command)
      Open3.capture3("bash", "-c", shell_command)
    end
  end
end
