import { Controller } from "@hotwired/stimulus"

// Checking "Training required" adds TRAINING REQUIRED to the label name,
// starting from the thing's name when the label name is blank. Unchecking
// leaves the label alone; people edit or remove the text like any other.
// Matches Thing#add_training_to_label_name.
export default class extends Controller {
  static targets = ["name", "label"]
  static values = { text: String, separator: String }

  add(event) {
    if (!event.target.checked || !this.hasLabelTarget) return

    const current = this.labelTarget.value.trim() || (this.hasNameTarget ? this.nameTarget.value.trim() : "")
    if (current.toUpperCase().includes(this.textValue)) return

    this.labelTarget.value = [current, this.textValue].filter(Boolean).join(this.separatorValue)
    this.labelTarget.dispatchEvent(new Event("input", { bubbles: true }))
  }
}
