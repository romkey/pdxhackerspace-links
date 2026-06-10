module Cups
  class Client
    class Error < StandardError; end

    def initialize(server: nil, runner: nil)
      @server = server.presence || SiteSetting.instance.cups_server
      @runner = runner || method(:run_command)
    end

    def reachable?
      _stdout, _stderr, status = @runner.call(env, "lpstat", "-r")
      status.success? && _stdout.include?("scheduler is running")
    rescue Errno::ENOENT
      false
    end

    def queue_names
      stdout, _stderr, status = @runner.call(env, "lpstat", "-a")
      return [] unless status.success?

      stdout.lines.filter_map do |line|
        line.split.first if line.match?(/\A\w/)
      end.uniq.sort
    end

    def print_file(path, printer:, title: nil, copies: 1)
      raise Error, "File not found" unless File.exist?(path)

      args = [
        "-d", printer.cups_name,
        "-n", copies.to_s,
        "-o", "media=#{printer.cups_media}",
        "-o", "fit-to-page"
      ]
      args.concat(["-t", title]) if title.present?

      _stdout, stderr, status = @runner.call(env, "lp", *args, path)
      raise Error, stderr.presence || "Print job failed" unless status.success?

      true
    end

    private

    def env
      { "CUPS_SERVER" => @server }
    end

    def run_command(*args)
      Open3.capture3(*args)
    end
  end
end
