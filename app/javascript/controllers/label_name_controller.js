import { Controller } from "@hotwired/stimulus"

// Shows the thing's name as the placeholder for its label name, so it's clear
// that leaving the label name blank prints the regular name.
export default class extends Controller {
  static targets = ["source", "field"]
  static values = { fallback: String }

  connect() {
    this.update()
  }

  update() {
    this.fieldTarget.placeholder = this.sourceTarget.value.trim() || this.fallbackValue
  }
}
