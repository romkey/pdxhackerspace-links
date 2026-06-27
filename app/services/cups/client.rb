module Cups
  class Client
    class Error < StandardError; end

    CONTINUOUS_MEDIA_FORMAT = /\ACustom\.(\d+)x0mm\z/
    FILTER_FAILURE_PATTERN = /filter failed|unable to send|page margins overlap|unknown option|unsupported/i

    def self.continuous_media?(media)
      CONTINUOUS_MEDIA_FORMAT.match?(media.to_s)
    end

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

    def print_file(path, printer:, title: nil, copies: 1, media: nil, page_width_mm: nil, page_height_mm: nil)
      raise Error, "File not found" unless File.exist?(path)

      media_name = media || resolve_media(printer, page_width_mm: page_width_mm, page_height_mm: page_height_mm)
      args = [
        "-d", printer.cups_name,
        "-n", copies.to_s,
        "-o", "media=#{media_name}",
        "-o", "PageSize=#{media_name}"
      ]
      args.concat(label_print_options(printer))
      args.concat([ "-t", title ]) if title.present?

      stdout, stderr, status = @runner.call({ "CUPS_SERVER" => printer.cups_server }, "lp", *args, path)
      output = [ stdout, stderr ].join("\n").strip
      raise Error, output.presence || "Print job failed" unless status.success?

      if (job_id = output[/request id is (\S+)/, 1])
        verify_job!(printer: printer, job_id: job_id)
      end

      true
    end

    def resolve_media(printer, page_width_mm: nil, page_height_mm: nil)
      media = printer.cups_media
      return media unless (match = CONTINUOUS_MEDIA_FORMAT.match(media))

      feed_length_mm = printer.landscape_label? ? page_width_mm : page_height_mm
      return media unless feed_length_mm

      "Custom.#{match[1]}x#{feed_length_mm.round}mm"
    end

    private

    def label_print_options(printer)
      return [] if printer.page_size == "letter"

      options = [
        "-o", "print-scaling=none",
        "-o", "pdfAutoRotate=off",
        "-o", "job-sheets=none"
      ]
      options.concat(extra_label_options)
      options
    end

    def extra_label_options
      ENV.fetch("CUPS_LABEL_OPTIONS", "").split(/\s+/).flat_map do |option|
        next [] if option.blank?

        option.split("=", 2).flat_map { |part| [ "-o", part ] }
      end
    end

    def verify_job!(printer:, job_id:)
      printer_env = { "CUPS_SERVER" => printer.cups_server }

      3.times do |attempt|
        sleep(0.5) if attempt.positive?
        stdout, _stderr, status = @runner.call(printer_env, "lpstat", "-l", "-o", job_id)
        next unless status.success?

        return if stdout.blank?

        raise Error, job_failure_message(job_id, stdout) if stdout.match?(FILTER_FAILURE_PATTERN)

        return if stdout.match?(/Status:\s*completed/i)
      end
    end

    def job_failure_message(job_id, details)
      reason = details[/Reason:\s*(.+)/i, 1] ||
               details[/Status:\s*(.+)/i, 1] ||
               details.lines.first.to_s.strip
      "Print job #{job_id} failed: #{reason}"
    end

    def env
      { "CUPS_SERVER" => @server }
    end

    def run_command(*args)
      Open3.capture3(*args)
    end
  end
end
