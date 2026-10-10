import { Controller } from "@hotwired/stimulus"

// Shows the thing form one step at a time. When editing, every step is
// reachable from the step list. When creating, steps open up as they're
// reached, so the step list only links back to steps already seen.
export default class extends Controller {
  static targets = ["step", "crumb"]
  static values = { editing: Boolean, index: Number, reached: Number }

  connect() {
    this.onInvalid = this.onInvalid.bind(this)
    this.element.addEventListener("invalid", this.onInvalid, true)

    const fromHash = this.indexForId(window.location.hash.slice(1))
    if (fromHash !== -1 && fromHash <= this.reachedValue) this.indexValue = fromHash

    this.render()
  }

  disconnect() {
    this.element.removeEventListener("invalid", this.onInvalid, true)
  }

  next(event) {
    event.preventDefault()
    if (!this.validateStep(this.indexValue)) return

    this.show(this.indexValue + 1)
  }

  back(event) {
    event.preventDefault()
    this.show(this.indexValue - 1)
  }

  jump(event) {
    event.preventDefault()
    const index = this.crumbTargets.indexOf(event.currentTarget)
    if (index === -1 || index > this.reachedValue) return
    if (index > this.indexValue && !this.validateStep(this.indexValue)) return

    this.show(index)
  }

  // While creating, Enter in a text field moves to the next step instead of
  // submitting a half-filled form. The last step submits as usual.
  enter(event) {
    if (this.editingValue || this.indexValue === this.lastIndex) return

    const field = event.target
    if (field.tagName !== "INPUT") return
    if (["button", "submit", "file"].includes(field.type)) return

    // Search fields drive their own pickers; Enter there must neither submit
    // nor advance.
    if (field.type === "search") {
      event.preventDefault()
      return
    }

    this.next(event)
  }

  // A required field on a hidden step can't show its own message, so open
  // its step and let the browser point at it.
  onInvalid(event) {
    const index = this.stepTargets.findIndex((step) => step.contains(event.target))
    if (index === -1 || index === this.indexValue || this.revealingInvalid) return

    this.revealingInvalid = true
    this.show(index)
    requestAnimationFrame(() => {
      this.revealingInvalid = false
      event.target.reportValidity()
    })
  }

  show(index) {
    this.indexValue = Math.max(0, Math.min(index, this.lastIndex))
    this.reachedValue = Math.max(this.reachedValue, this.indexValue)
    this.render()
    history.replaceState(history.state, "", `#${this.stepTargets[this.indexValue].id}`)
    this.element.scrollIntoView({ block: "start", behavior: "smooth" })
  }

  render() {
    this.stepTargets.forEach((step, index) => {
      step.hidden = index !== this.indexValue
    })

    this.crumbTargets.forEach((crumb, index) => {
      const current = index === this.indexValue

      if (index <= this.reachedValue) {
        crumb.setAttribute("href", `#${this.stepTargets[index].id}`)
      } else {
        crumb.removeAttribute("href")
      }

      crumb.classList.toggle("active", current)
      if (current) {
        crumb.setAttribute("aria-current", "step")
      } else {
        crumb.removeAttribute("aria-current")
      }
    })
  }

  validateStep(index) {
    const fields = this.stepTargets[index].querySelectorAll("input, select, textarea")
    const invalid = Array.from(fields).find((field) => !field.checkValidity())
    if (!invalid) return true

    invalid.reportValidity()
    return false
  }

  indexForId(id) {
    return this.stepTargets.findIndex((step) => step.id === id)
  }

  get lastIndex() {
    return this.stepTargets.length - 1
  }
}
