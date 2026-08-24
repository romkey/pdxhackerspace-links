module Links
  module Version
    module_function

    def current
      ENV.fetch("APP_VERSION") do
        File.read(Rails.root.join("VERSION")).strip
      rescue Errno::ENOENT
        "dev"
      end
    end

    def display(version = current)
      value = version.to_s
      return value if value.in?(%w[dev staging])

      value.start_with?("v") ? value : "v#{value}"
    end

    def release_tag(version = current)
      value = version.to_s
      return if value.blank? || value.in?(%w[dev staging])

      value.start_with?("v") ? value : "v#{value}"
    end
  end
end
