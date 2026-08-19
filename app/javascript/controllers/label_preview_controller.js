import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "frame", "leftMargin", "rightMargin", "middleGap", "printForm" ]
  static values = {
    previewPath: String,
    mediaFormat: String
  }

  connect() {
    if (this.hasMarginControls()) {
      this.scheduleRefresh()
    }
  }

  disconnect() {
    clearTimeout(this.refreshTimeout)
  }

  update() {
    this.scheduleRefresh()
  }

  scheduleRefresh() {
    clearTimeout(this.refreshTimeout)
    this.refreshTimeout = setTimeout(() => this.refreshPreview(), 250)
  }

  refreshPreview() {
    const url = this.buildPreviewUrl()
    this.frameTarget.src = url

    if (this.hasPrintFormTarget) {
      this.syncPrintFormParams(url)
    }
  }

  buildPreviewUrl() {
    const url = new URL(this.previewPathValue, window.location.origin)
    url.searchParams.set("format", this.mediaFormatValue)

    if (this.hasLeftMarginTarget) {
      const left = this.leftMarginTarget.value.trim()
      if (left !== "") url.searchParams.set("left_margin_mm", left)
    }

    if (this.hasRightMarginTarget) {
      const right = this.rightMarginTarget.value.trim()
      if (right !== "") url.searchParams.set("right_margin_mm", right)
    }

    if (this.hasMiddleGapTarget) {
      const gap = this.middleGapTarget.value.trim()
      if (gap !== "") url.searchParams.set("cable_tag_gap_mm", gap)
    }

    url.searchParams.set("_", Date.now().toString())
    return url.toString()
  }

  syncPrintFormParams(url) {
    const previewUrl = new URL(url)

    this.printParamNames().forEach((name) => {
      const existing = this.printFormTarget.querySelector(`input[name='${name}']`)

      if (!previewUrl.searchParams.has(name)) {
        existing?.remove()
        return
      }

      let input = existing
      if (!input) {
        input = document.createElement("input")
        input.type = "hidden"
        input.name = name
        this.printFormTarget.appendChild(input)
      }

      input.value = previewUrl.searchParams.get(name)
    })
  }

  printParamNames() {
    const names = [ "layout" ]
    if (this.hasLeftMarginTarget) names.push("left_margin_mm")
    if (this.hasRightMarginTarget) names.push("right_margin_mm")
    if (this.hasMiddleGapTarget) names.push("cable_tag_gap_mm")
    return names
  }

  hasMarginControls() {
    return this.hasLeftMarginTarget || this.hasRightMarginTarget || this.hasMiddleGapTarget
  }
}
