// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import * as bootstrapModule from "bootstrap"

if (!window.bootstrap?.Modal) {
  window.bootstrap = bootstrapModule.default ?? bootstrapModule
}

import "controllers"
