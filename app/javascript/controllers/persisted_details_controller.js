import { Controller } from "@hotwired/stimulus"

// Remembers whether a <details> element is open or closed, per browser.
export default class extends Controller {
  static values = { key: String }

  connect() {
    const stored = this.read()
    if (stored !== null) this.element.open = stored === "true"
  }

  save() {
    try {
      localStorage.setItem(this.keyValue, String(this.element.open))
    } catch (_error) {
      // Storage unavailable (private mode, blocked); the toggle still works for this page.
    }
  }

  read() {
    try {
      return localStorage.getItem(this.keyValue)
    } catch (_error) {
      return null
    }
  }
}
