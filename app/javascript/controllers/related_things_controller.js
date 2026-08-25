import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "results", "container", "template", "item", "destroyField", "relatedIdField"]
  static values = {
    searchUrl: String,
    excludeId: String
  }

  connect() {
    this.debounceTimer = null
    this.activeIndex = -1
    this.boundClickOutside = this.clickOutside.bind(this)
    document.addEventListener("click", this.boundClickOutside)
  }

  disconnect() {
    document.removeEventListener("click", this.boundClickOutside)
  }

  input() {
    clearTimeout(this.debounceTimer)
    this.debounceTimer = setTimeout(() => this.fetchResults(), 200)
  }

  keydown(event) {
    const items = this.resultItems()

    if (event.key === "ArrowDown") {
      event.preventDefault()
      this.activeIndex = Math.min(this.activeIndex + 1, items.length - 1)
      this.highlightActive(items)
    } else if (event.key === "ArrowUp") {
      event.preventDefault()
      this.activeIndex = Math.max(this.activeIndex - 1, 0)
      this.highlightActive(items)
    } else if (event.key === "Enter") {
      if (this.activeIndex >= 0 && items[this.activeIndex]) {
        event.preventDefault()
        this.selectItem(items[this.activeIndex])
      }
    } else if (event.key === "Escape") {
      this.hideResults()
    }
  }

  async fetchResults() {
    const query = this.inputTarget.value.trim()
    if (query.length === 0) {
      this.hideResults()
      return
    }

    const url = new URL(this.searchUrlValue, window.location.origin)
    url.searchParams.set("q", query)
    if (this.hasExcludeIdValue && this.excludeIdValue) {
      url.searchParams.set("exclude_id", this.excludeIdValue)
    }

    const response = await fetch(url, {
      headers: { Accept: "application/json" }
    })

    if (!response.ok) {
      this.hideResults()
      return
    }

    const things = await response.json()
    this.renderResults(things)
  }

  renderResults(things) {
    const selectedIds = this.selectedRelatedIds()
    const available = things.filter((thing) => !selectedIds.has(String(thing.id)))

    if (available.length === 0) {
      this.resultsTarget.innerHTML = '<div class="list-group-item text-12 text-secondary py-2">No matches</div>'
      this.showResults()
      return
    }

    this.resultsTarget.innerHTML = available.map((thing) => {
      const subtitle = this.subtitleFor(thing)
      return `
        <button type="button"
                class="list-group-item list-group-item-action py-2 text-start"
                data-action="related-things#pick"
                data-related-things-id-param="${thing.id}"
                data-related-things-name-param="${this.escapeHtml(thing.name)}">
          <div class="text-13">${this.escapeHtml(thing.name)}</div>
          ${subtitle ? `<div class="text-12 text-secondary">${this.escapeHtml(subtitle)}</div>` : ""}
        </button>
      `
    }).join("")

    this.activeIndex = -1
    this.showResults()
  }

  pick(event) {
    event.preventDefault()
    this.addRelationship(event.params.id, event.params.name)
    this.inputTarget.value = ""
    this.hideResults()
  }

  addRelationship(id, name) {
    if (this.selectedRelatedIds().has(String(id))) return

    const content = this.templateTarget.innerHTML
      .replace(/NEW_RECORD/g, new Date().getTime().toString())
      .replace(/__RELATED_ID__/g, id)
      .replace(/__RELATED_NAME__/g, this.escapeHtml(name))

    this.containerTarget.insertAdjacentHTML("beforeend", content)
  }

  remove(event) {
    event.preventDefault()
    const item = event.target.closest("[data-related-things-target='item']")
    const destroyField = item.querySelector("[data-related-things-target='destroyField']")

    if (destroyField) {
      destroyField.value = "1"
      item.classList.add("d-none")
    } else {
      item.remove()
    }
  }

  clickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.hideResults()
    }
  }

  selectItem(item) {
    this.addRelationship(item.dataset.relatedThingsIdParam, item.dataset.relatedThingsNameParam)
    this.inputTarget.value = ""
    this.hideResults()
  }

  resultItems() {
    return Array.from(this.resultsTarget.querySelectorAll("[data-related-things-id-param]"))
  }

  highlightActive(items) {
    items.forEach((item, index) => {
      item.classList.toggle("active", index === this.activeIndex)
    })
  }

  selectedRelatedIds() {
    return new Set(
      this.relatedIdFieldTargets
        .filter((field) => {
          const item = field.closest("[data-related-things-target='item']")
          return item && !item.classList.contains("d-none")
        })
        .map((field) => field.value)
        .filter(Boolean)
    )
  }

  subtitleFor(thing) {
    const parts = [thing.owner, thing.manufacturer, thing.model].filter(Boolean)
    return parts.join(" · ")
  }

  showResults() {
    this.resultsTarget.classList.remove("d-none")
  }

  hideResults() {
    this.resultsTarget.classList.add("d-none")
    this.resultsTarget.innerHTML = ""
    this.activeIndex = -1
  }

  escapeHtml(value) {
    return String(value)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
  }
}
