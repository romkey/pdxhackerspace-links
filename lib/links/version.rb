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
  end
end
