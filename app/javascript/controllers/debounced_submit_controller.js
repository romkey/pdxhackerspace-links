import { Controller } from "@hotwired/stimulus"

// Submits the form after the user pauses typing.
//
// When the form lives inside the Turbo Frame it updates, each response
// replaces the input the user is typing in. To keep that usable, the focused
// field is carried across the frame render: the new field gets the user's
// current text (including anything typed while the request was in flight),
// focus and the caret position. If the text has moved on since the request
// was sent, another search is queued. Staleness is judged against what was
// submitted, not what the server echoed back, because the server may
// normalize the value (e.g. strip whitespace).
let pendingRestore = null
let lastSubmitted = null

export default class extends Controller {
  static values = { delay: { type: Number, default: 300 } }

  connect() {
    this.timeout = null
    this.restoreFocusedField()
  }

  disconnect() {
    if (this.timeout) clearTimeout(this.timeout)
  }

  submit() {
    if (this.timeout) clearTimeout(this.timeout)
    this.timeout = setTimeout(() => {
      lastSubmitted = new FormData(this.element)
      this.element.requestSubmit()
    }, this.delayValue)
  }

  // turbo:before-frame-render@document
  preserveFocusedField(event) {
    const field = document.activeElement
    if (!field?.id || !this.element.contains(field)) return

    const newField = event.detail.newFrame?.querySelector(`#${CSS.escape(field.id)}`)
    if (!newField) return

    const submittedValue = lastSubmitted?.get(field.name)
    pendingRestore = {
      id: field.id,
      selectionStart: field.selectionStart,
      selectionEnd: field.selectionEnd,
      stale: submittedValue != null && submittedValue !== field.value
    }
    lastSubmitted = null
    newField.value = field.value
  }

  restoreFocusedField() {
    if (!pendingRestore) return

    const field = this.element.querySelector(`#${CSS.escape(pendingRestore.id)}`)
    if (!field) return

    const { selectionStart, selectionEnd, stale } = pendingRestore
    pendingRestore = null

    field.focus({ preventScroll: true })
    try {
      field.setSelectionRange(selectionStart, selectionEnd)
    } catch {
      // Some input types don't support selection; focus alone is fine.
    }

    if (stale) this.submit()
  }
}
