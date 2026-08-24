module Links
  module Version
    module_function

    def current
      normalize_version(
        ENV.fetch("APP_VERSION") do
          File.read(Rails.root.join("VERSION")).strip
        rescue Errno::ENOENT
          "dev"
        end
      )
    end

    def display(version = current)
      normalize_version(version)
    end

    def release_tag(version = current)
      value = version.to_s
      return if value.blank? || value.in?(%w[dev staging])

      value.start_with?("v") ? value : "v#{value}"
    end

    def normalize_version(value)
      value = value.to_s.strip
      return value if value.in?(%w[dev staging])

      value.delete_prefix("v")
    end
  end
end
