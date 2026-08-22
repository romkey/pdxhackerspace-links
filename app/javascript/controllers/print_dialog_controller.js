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
    bulkPrintUrl: String
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
    event.preventDefault()
    const trigger = event.currentTarget
    const modal = this.ensureModal()
    if (!modal) return

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
    modal.show()
  }

  layoutChanged() {
    this.syncLayoutOptions()
    this.syncPrinterOptions()
  }

  printerChanged() {
    // layout-dependent printer list already synced on layout change
  }

  preview() {
    if (this.bulkMode) return

    const url = this.buildPreviewUrl()
    if (url) window.location.href = url
  }

  submit() {
    this.formTarget.action = this.printPath
    this.formTarget.method = "post"

    this.clearHiddenFields()
    this.appendHidden("authenticity_token", this.csrfToken())

    if (this.bulkMode) {
      if (this.selectAllMatching) {
        this.appendHidden("select_all", "1")
        Object.entries(this.filterParams).forEach(([ key, value ]) => {
          if (key === "filter" && value && typeof value === "object") {
            Object.entries(value).forEach(([ filterKey, filterValue ]) => {
              if (Array.isArray(filterValue)) {
                filterValue.forEach((entry) => this.appendHidden(`filter[${filterKey}][]`, entry))
              } else {
                this.appendHidden(`filter[${filterKey}]`, filterValue)
              }
            })
          } else if (value != null && value !== "") {
            this.appendHidden(key, value)
          }
        })
      } else {
        this.selectedThingIds.forEach((id) => this.appendHidden("thing_ids[]", id))
      }
    }

    this.formTarget.requestSubmit()
    this.ensureModal()?.hide()
  }

  syncBulkFields() {
    this.bulkFieldsTarget.classList.toggle("d-none", !this.bulkMode)
    this.previewButtonTarget.classList.toggle("d-none", this.bulkMode)
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

  ensureModal() {
    const element = this.modalElement()
    if (!element) return null

    const Modal = window.bootstrap?.Modal
    if (!Modal) return null

    return Modal.getOrCreateInstance(element)
  }
}
