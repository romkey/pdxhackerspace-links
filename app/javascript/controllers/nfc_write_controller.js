import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["writeButton", "status"]
  static values = {
    url: String,
    json: String,
    jsonTruncated: Boolean
  }

  connect() {
    if (this.webNfcAvailable() && this.hasWriteButtonTarget) {
      this.writeButtonTarget.classList.remove("d-none")
    }
  }

  write(event) {
    event.preventDefault()
    if (!this.webNfcAvailable()) return

    this.writeTag()
  }

  async writeTag() {
    this.setStatus("Hold phone to tag…", "secondary")

    try {
      const ndef = new NDEFReader()
      await ndef.write({
        records: [
          { recordType: "url", data: this.urlValue },
          { recordType: "mime", mediaType: "application/json", data: this.jsonValue }
        ]
      })

      const suffix = this.jsonTruncatedValue ? " Metadata was shortened to fit the tag." : ""
      this.setStatus(`Tag written.${suffix}`, "success")
    } catch (error) {
      this.setStatus(this.errorMessage(error), "warning")
    }
  }

  webNfcAvailable() {
    return "NDEFReader" in window
  }

  errorMessage(error) {
    const name = error?.name || ""

    if (name === "NotAllowedError") return "NFC permission denied."
    if (name === "NotSupportedError") return "NFC is not available on this device."
    if (name === "NetworkError") return "Lost contact with tag — try again."

    return error?.message || "Could not write tag."
  }

  setStatus(message, tone) {
    if (!this.hasStatusTarget) return

    this.statusTarget.textContent = message
    this.statusTarget.className = `text-13 text-${tone} mt-1`
    this.statusTarget.classList.remove("d-none")
  }
}
