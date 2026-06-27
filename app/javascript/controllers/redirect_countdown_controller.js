import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String, seconds: Number }
  static targets = [ "countdown" ]

  connect () {
    this.remaining = this.secondsValue
    this.renderCountdown()
    this.timer = window.setInterval(() => this.tick(), 1000)
  }

  disconnect () {
    window.clearInterval(this.timer)
  }

  tick () {
    this.remaining -= 1

    if (this.remaining <= 0) {
      window.clearInterval(this.timer)
      window.location.assign(this.urlValue)
      return
    }

    this.renderCountdown()
  }

  renderCountdown () {
    this.countdownTarget.textContent = String(this.remaining)
  }
}
