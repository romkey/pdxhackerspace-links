import { Controller } from "@hotwired/stimulus"

// Searches things and links each result to a URL built from a template, e.g.
// picking the second thing to merge in.
export default class extends Controller {
  static targets = ["input", "results"]
  static values = {
    searchUrl: String,
    excludeId: String,
    selectUrlTemplate: String
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
        items[this.activeIndex].click()
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

    this.renderResults(await response.json())
  }

  renderResults(things) {
    if (things.length === 0) {
      this.resultsTarget.innerHTML = '<div class="list-group-item text-12 text-secondary py-2">No matches</div>'
      this.showResults()
      return
    }

    this.resultsTarget.innerHTML = things.map((thing) => {
      const subtitle = this.subtitleFor(thing)
      return `
        <a class="list-group-item list-group-item-action py-2"
           href="${this.escapeHtml(this.selectUrlFor(thing.id))}">
          <div class="text-13">${this.escapeHtml(thing.name)}</div>
          ${subtitle ? `<div class="text-12 text-secondary">${this.escapeHtml(subtitle)}</div>` : ""}
        </a>
      `
    }).join("")

    this.activeIndex = -1
    this.showResults()
  }

  selectUrlFor(id) {
    return this.selectUrlTemplateValue.replace("__SOURCE__", encodeURIComponent(id))
  }

  clickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.hideResults()
    }
  }

  resultItems() {
    return Array.from(this.resultsTarget.querySelectorAll("a.list-group-item-action"))
  }

  highlightActive(items) {
    items.forEach((item, index) => {
      item.classList.toggle("active", index === this.activeIndex)
    })
  }

  subtitleFor(thing) {
    return [thing.owner, thing.manufacturer, thing.model].filter(Boolean).join(" · ")
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
