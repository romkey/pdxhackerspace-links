import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "selectToggle",
    "checkboxColumn",
    "headerCheckbox",
    "rowCheckbox",
    "actionBar",
    "selectionCount",
    "selectAllMatching",
    "selectAllMatchingCount",
    "printButton"
  ]

  static values = {
    totalCount: Number,
    filterParams: Object
  }

  connect() {
    this.selectionMode = false
    this.selectAllMatchingActive = false
    this.updateUI()
  }

  toggleSelectionMode() {
    this.selectionMode = !this.selectionMode
    if (!this.selectionMode) this.clearSelection()
    this.updateUI()
  }

  toggleRow() {
    this.selectAllMatchingActive = false
    this.updateUI()
  }

  togglePageAll(event) {
    const checked = event.target.checked
    this.rowCheckboxTargets.forEach((checkbox) => {
      checkbox.checked = checked
    })
    this.selectAllMatchingActive = false
    this.updateUI()
  }

  selectAllMatching(event) {
    event.preventDefault()
    this.rowCheckboxTargets.forEach((checkbox) => {
      checkbox.checked = true
    })
    this.selectAllMatchingActive = true
    this.updateUI()
  }

  clearSelection(event) {
    event?.preventDefault()
    this.rowCheckboxTargets.forEach((checkbox) => {
      checkbox.checked = false
    })
    if (this.hasHeaderCheckboxTarget) this.headerCheckboxTarget.checked = false
    this.selectAllMatchingActive = false
    this.updateUI()
  }

  prepareBulkPrint(event) {
    const trigger = event.currentTarget
    const count = this.selectAllMatchingActive ? this.totalCountValue : this.selectedIds().length

    trigger.dataset.bulk = "true"
    trigger.dataset.selectionCount = count
    trigger.dataset.thingIds = JSON.stringify(this.selectedIds())
    trigger.dataset.selectAllMatching = this.selectAllMatchingActive ? "true" : "false"
    trigger.dataset.filterParams = JSON.stringify(this.filterParamsValue)
    trigger.dataset.cableTagEligible = "true"
  }

  prepareBulkSubmit(event) {
    const form = event.target
    form.querySelectorAll("[data-dynamic-selection]").forEach((input) => input.remove())
    this.appendBulkSelection((name, value) => this.appendHiddenField(form, name, value))
  }

  appendBulkSelection(append) {
    if (this.selectAllMatchingActive) {
      append("select_all", "1")
      Object.entries(this.filterParamsValue).forEach(([ key, value ]) => {
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
      this.selectedIds().forEach((id) => append("thing_ids[]", id))
    }
  }

  appendHiddenField(form, name, value) {
    const input = document.createElement("input")
    input.type = "hidden"
    input.name = name
    input.value = value
    input.dataset.dynamicSelection = "true"
    form.appendChild(input)
  }

  selectedIds() {
    return this.rowCheckboxTargets.filter((checkbox) => checkbox.checked).map((checkbox) => checkbox.value)
  }

  updateUI() {
    const visible = this.selectionMode
    this.checkboxColumnTargets.forEach((column) => column.classList.toggle("d-none", !visible))
    this.actionBarTarget.classList.toggle("d-none", !visible || this.selectedCount() === 0)

    if (this.hasSelectToggleTarget) {
      this.selectToggleTarget.textContent = visible ? "Done" : "Select"
      this.selectToggleTarget.classList.toggle("active", visible)
    }

    if (this.hasHeaderCheckboxTarget) {
      const selectedOnPage = this.rowCheckboxTargets.filter((checkbox) => checkbox.checked).length
      const allOnPage = selectedOnPage === this.rowCheckboxTargets.length && this.rowCheckboxTargets.length > 0
      this.headerCheckboxTarget.checked = allOnPage
      this.headerCheckboxTarget.indeterminate = selectedOnPage > 0 && !allOnPage
    }

    if (this.hasSelectionCountTarget) {
      const count = this.selectAllMatchingActive ? this.totalCountValue : this.selectedCount()
      this.selectionCountTarget.textContent = count
    }

    if (this.hasSelectAllMatchingTarget) {
      const showBanner = visible &&
        !this.selectAllMatchingActive &&
        this.selectedCount() === this.rowCheckboxTargets.length &&
        this.rowCheckboxTargets.length > 0 &&
        this.totalCountValue > this.rowCheckboxTargets.length

      this.selectAllMatchingTarget.classList.toggle("d-none", !showBanner)
      if (this.hasSelectAllMatchingCountTarget) {
        this.selectAllMatchingCountTarget.textContent = this.totalCountValue
      }
    }

    if (this.hasPrintButtonTarget) {
      this.printButtonTarget.disabled = this.selectedCount() === 0 && !this.selectAllMatchingActive
    }
  }

  selectedCount() {
    return this.rowCheckboxTargets.filter((checkbox) => checkbox.checked).length
  }
}
