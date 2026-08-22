import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "title",
    "form",
    "bulkFields",
    "layoutRadio",
    "printerSelect",
    "previewButton",
    "submitButton",
    "cableTagHint"
  ]

  static values = {
    printers: Array,
    bulkPrintUrl: String,
    bulkPreviewUrl: String
  }

  connect() {
    this.bulkMode = false
    this.previewPathTemplate = null
    this.printPath = null
    this.cableTagEligible = true
    this.selectedThingIds = []
    this.selectAllMatching = false
    this.filterParams = {}
  }

  open(event) {
    const trigger = event.currentTarget

    this.bulkMode = trigger.dataset.bulk === "true"
    this.printPath = this.bulkMode ? this.bulkPrintUrlValue : trigger.dataset.printUrl
    this.previewPathTemplate = trigger.dataset.previewUrlTemplate || null
    this.cableTagEligible = trigger.dataset.cableTagEligible !== "false"
    this.selectedThingIds = JSON.parse(trigger.dataset.thingIds || "[]")
    this.selectAllMatching = trigger.dataset.selectAllMatching === "true"
    this.filterParams = JSON.parse(trigger.dataset.filterParams || "{}")

    this.titleTarget.textContent = this.bulkMode
      ? `Print ${trigger.dataset.selectionCount} labels`
      : `Print label — ${trigger.dataset.thingName}`

    this.syncBulkFields()
    this.syncLayoutOptions()
    this.syncPrinterOptions()
  }

  layoutChanged() {
    this.syncLayoutOptions()
    this.syncPrinterOptions()
  }

  printerChanged() {
    // layout-dependent printer list already synced on layout change
  }

  preview() {
    const url = this.bulkMode ? this.buildBulkPreviewUrl() : this.buildPreviewUrl()
    if (!url) return

    this.dismissModal()
    window.location.href = url
  }

  submit() {
    this.formTarget.action = this.printPath
    this.formTarget.method = "post"

    this.clearHiddenFields()
    this.appendHidden("authenticity_token", this.csrfToken())

    if (this.bulkMode) {
      this.appendBulkSelection((name, value) => this.appendHidden(name, value))
    }

    this.formTarget.requestSubmit()
    this.dismissModal()
  }

  syncBulkFields() {
    this.bulkFieldsTarget.classList.toggle("d-none", !this.bulkMode)
  }

  syncLayoutOptions() {
    const cableTagRadio = this.layoutRadioTargets.find((radio) => radio.value === "cable_tag")
    if (!cableTagRadio) return

    const disableCableTag = !this.cableTagEligible
    cableTagRadio.disabled = disableCableTag
    this.cableTagHintTarget.classList.toggle("d-none", !disableCableTag)

    if (disableCableTag && cableTagRadio.checked) {
      const standard = this.layoutRadioTargets.find((radio) => radio.value === "standard")
      if (standard) standard.checked = true
    }
  }

  syncPrinterOptions() {
    const layout = this.selectedLayout()
    const eligible = this.printersValue.filter((printer) => {
      if (layout !== "cable_tag") return true
      return printer.cable_tag_capable
    })

    const current = this.printerSelectTarget.value
    this.printerSelectTarget.innerHTML = ""

    eligible.forEach((printer) => {
      const option = document.createElement("option")
      option.value = printer.id
      option.textContent = printer.name
      this.printerSelectTarget.appendChild(option)
    })

    if (eligible.some((printer) => String(printer.id) === current)) {
      this.printerSelectTarget.value = current
    }
  }

  selectedLayout() {
    return this.layoutRadioTargets.find((radio) => radio.checked)?.value || "standard"
  }

  selectedPrinterId() {
    return this.printerSelectTarget.value
  }

  buildPreviewUrl() {
    if (!this.previewPathTemplate) return null

    const url = new URL(
      this.previewPathTemplate.replace("__PRINTER__", this.selectedPrinterId()),
      window.location.origin
    )

    const layout = this.selectedLayout()
    if (layout !== "standard") url.searchParams.set("layout", layout)

    const markLabelled = this.formTarget.querySelector("input[name='mark_labelled']")
    if (markLabelled?.checked) url.searchParams.set("mark_labelled", "1")

    return url.toString()
  }

  buildBulkPreviewUrl() {
    if (!this.hasBulkPreviewUrlValue) return null

    const url = new URL(this.bulkPreviewUrlValue, window.location.origin)
    url.searchParams.set("printer_id", this.selectedPrinterId())

    const layout = this.selectedLayout()
    if (layout !== "standard") url.searchParams.set("layout", layout)

    this.appendBulkSelection((name, value) => {
      url.searchParams.append(name, value)
    })

    return url.toString()
  }

  appendBulkSelection(append) {
    if (this.selectAllMatching) {
      append("select_all", "1")
      Object.entries(this.filterParams).forEach(([ key, value ]) => {
        if (key === "filter" && value && typeof value === "object") {
          Object.entries(value).forEach(([ filterKey, filterValue ]) => {
            if (Array.isArray(filterValue)) {
              filterValue.forEach((entry) => append(`filter[${filterKey}][]`, entry))
            } else {
              append(`filter[${filterKey}]`, filterValue)
            }
          })
        } else if (value != null && value !== "") {
          append(key, value)
        }
      })
    } else {
      this.selectedThingIds.forEach((id) => append("thing_ids[]", id))
    }
  }

  appendHidden(name, value) {
    const input = document.createElement("input")
    input.type = "hidden"
    input.name = name
    input.value = value
    this.formTarget.appendChild(input)
  }

  clearHiddenFields() {
    this.formTarget.querySelectorAll("input[type='hidden']").forEach((input) => input.remove())
  }

  csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content
  }

  modalElement() {
    return this.element.querySelector("#print-label-dialog")
  }

  dismissModal() {
    this.modalElement()?.querySelector("[data-bs-dismiss=\"modal\"]")?.click()
  }
}
