import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "image"]

  open(event) {
    event.preventDefault()
    const url = event.currentTarget.dataset.lightboxUrlValue || event.currentTarget.href
    this.imageTarget.src = url
    window.bootstrap.Modal.getOrCreateInstance(this.modalTarget).show()
  }
}
