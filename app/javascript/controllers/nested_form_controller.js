import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "template", "item", "destroyField"]

  add(event) {
    event.preventDefault()
    const content = this.templateTarget.innerHTML.replace(/NEW_RECORD/g, new Date().getTime().toString())
    this.containerTarget.insertAdjacentHTML("beforeend", content)
  }

  remove(event) {
    event.preventDefault()
    const item = event.target.closest("[data-nested-form-target='item']")
    const destroyField = item.querySelector("[data-nested-form-target='destroyField']")

    if (destroyField) {
      destroyField.value = "1"
      item.classList.add("d-none")
    } else {
      item.remove()
    }
  }
}
