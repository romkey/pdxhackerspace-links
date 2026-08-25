import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { href: String }

  navigate(event) {
    if (event.target.closest("a, button, input, label, .dropdown-menu, [data-clickable-row-ignore]")) return
    window.location = this.hrefValue
  }
}
