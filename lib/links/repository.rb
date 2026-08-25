module Links
  module Repository
    DEFAULT_URL = "https://github.com/romkey/pdxhackerspace-links"

    module_function

    def url
      ENV.fetch("GITHUB_REPO_URL", DEFAULT_URL)
    end

    def release_url(version)
      tag = Links::Version.release_tag(version)
      return url if tag.blank?

      "#{url}/releases/tag/#{tag}"
    end
  end
end
