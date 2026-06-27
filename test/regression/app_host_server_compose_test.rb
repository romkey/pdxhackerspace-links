require "test_helper"

class AppHostServerComposeRegressionTest < ActiveSupport::TestCase
  COMPOSE_PATH = Rails.root.join("docker-compose.server.yml")

  test "server compose passes APP_HOST to web and sidekiq" do
    compose = YAML.load_file(COMPOSE_PATH)
    services = compose.fetch("services")

    %w[web sidekiq].each do |service_name|
      environment = services.fetch(service_name).fetch("environment")

      assert_includes environment.keys, "APP_HOST", "#{service_name} must pass APP_HOST into the container"
      assert_match(/\$\{APP_HOST/, environment.fetch("APP_HOST"))
    end
  end
end
