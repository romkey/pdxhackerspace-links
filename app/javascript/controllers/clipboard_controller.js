import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { text: String }

  copy() {
    navigator.clipboard.writeText(this.textValue).then(() => {
      const original = this.element.innerHTML
      this.element.innerHTML = '<i class="bi bi-check-lg"></i>'
      setTimeout(() => { this.element.innerHTML = original }, 1500)
    })
  }
}
