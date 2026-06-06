source "https://rubygems.org"

gem "rails", "~> 8.1.3"
gem "propshaft"
gem "pg", "~> 1.1"
gem "puma", ">= 5.0"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "cssbundling-rails"

gem "bcrypt", "~> 3.1.7"
gem "dotenv-rails"
gem "omniauth", "~> 2.1"
gem "omniauth_openid_connect", "~> 0.8"
gem "omniauth-rails_csrf_protection"
gem "redis", "~> 5.4"
gem "sidekiq", "~> 8.0"

gem "tzinfo-data", platforms: %i[ windows jruby ]

gem "bootsnap", require: false
gem "thruster", require: false
gem "image_processing", "~> 1.2"

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "bundler-audit", require: false
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
end

group :development do
  gem "web-console"
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
end
