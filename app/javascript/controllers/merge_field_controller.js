import { Controller } from "@hotwired/stimulus"

// Fills a merge conflict field with one side's value, leaving it editable.
export default class extends Controller {
  static targets = ["input"]

  use(event) {
    event.preventDefault()
    this.inputTarget.value = event.params.value
    this.inputTarget.focus()
  }
}
