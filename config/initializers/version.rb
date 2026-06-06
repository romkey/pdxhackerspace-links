require Rails.root.join("lib/links/version")

Rails.application.config.app_version = Links::Version.current
