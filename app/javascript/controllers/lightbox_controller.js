import { Controller } from "@hotwired/stimulus"
import { Modal } from "bootstrap"

export default class extends Controller {
  static targets = ["modal", "image"]

  open(event) {
    event.preventDefault()
    const url = event.currentTarget.dataset.lightboxUrlValue || event.currentTarget.href
    this.imageTarget.src = url
    Modal.getOrCreateInstance(this.modalTarget).show()
  }
}
