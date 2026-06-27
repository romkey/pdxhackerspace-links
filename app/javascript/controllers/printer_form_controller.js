import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "cupsSection",
    "commandSection",
    "cupsServer",
    "cupsName",
    "pageSize",
    "averySection",
    "labelHeight",
    "printCommand"
  ]

  connect() {
    this.sync()
  }

  sync() {
    const type = this.element.querySelector('input[name="printer[printer_type]"]:checked')?.value || "cups"
    const cups = type === "cups"

    this.cupsSectionTargets.forEach((section) => {
      section.hidden = !cups
      this.setFieldsDisabled(section, !cups)
    })
    this.commandSectionTarget.hidden = cups
    this.setFieldsDisabled(this.commandSectionTarget, cups)
    this.averySectionTarget.hidden = !cups
    this.setFieldsDisabled(this.averySectionTarget, !cups)

    this.cupsServerTarget.required = cups
    this.cupsNameTarget.required = cups
    this.pageSizeTargets.forEach((input) => {
      input.required = cups
    })
    this.labelHeightTarget.required = !cups
    this.printCommandTarget.required = !cups
  }

  setFieldsDisabled(section, disabled) {
    section.querySelectorAll("input, select, textarea").forEach((input) => {
      input.disabled = disabled
    })
  }
}
