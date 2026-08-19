import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "frame", "leftMargin", "rightMargin", "middleGap", "printForm" ]
  static values = {
    previewPath: String,
    mediaFormat: String
  }

  connect() {
    this.scheduleRefresh()
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

    const left = this.leftMarginTarget.value.trim()
    const right = this.rightMarginTarget.value.trim()
    if (left !== "") url.searchParams.set("left_margin_mm", left)
    if (right !== "") url.searchParams.set("right_margin_mm", right)

    if (this.hasMiddleGapTarget) {
      const gap = this.middleGapTarget.value.trim()
      if (gap !== "") url.searchParams.set("cable_tag_gap_mm", gap)
    }

    url.searchParams.set("_", Date.now().toString())
    return url.toString()
  }

  syncPrintFormParams(url) {
    const previewUrl = new URL(url)
    ;[ "left_margin_mm", "right_margin_mm", "cable_tag_gap_mm", "layout" ].forEach((name) => {
      const input = this.printFormTarget.querySelector(`input[name='${name}']`)
      if (!input) return

      if (previewUrl.searchParams.has(name)) {
        input.value = previewUrl.searchParams.get(name)
      } else {
        input.value = ""
      }
    })
  }
}
