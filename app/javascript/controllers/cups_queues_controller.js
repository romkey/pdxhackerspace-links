import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "server", "queue", "list", "status", "refreshButton" ]
  static values = { url: String }

  refreshQueues() {
    const server = this.serverTarget.value.trim()
    if (!server) {
      this.statusTarget.textContent = "Enter a CUPS server address to load queues"
      return
    }

    this.statusTarget.textContent = "Checking CUPS server…"
    this.setRefreshing(true)

    fetch(`${this.urlValue}?${new URLSearchParams({ server })}`, {
      headers: { Accept: "application/json" }
    })
      .then((response) => {
        if (!response.ok) throw new Error("bad request")
        return response.json()
      })
      .then((data) => {
        this.updateQueueList(data.queues || [])
        this.statusTarget.textContent = data.reachable
          ? `${data.queues.length} queue${data.queues.length === 1 ? "" : "s"} found`
          : "Cannot reach CUPS server — enter the queue name manually"
      })
      .catch(() => {
        this.statusTarget.textContent = "Could not load queues — enter the queue name manually"
      })
      .finally(() => {
        this.setRefreshing(false)
      })
  }

  setRefreshing(refreshing) {
    if (!this.hasRefreshButtonTarget) return

    this.refreshButtonTarget.disabled = refreshing
  }

  updateQueueList(queues) {
    this.listTarget.innerHTML = ""
    queues.forEach((queue) => {
      const option = document.createElement("option")
      option.value = queue
      this.listTarget.appendChild(option)
    })
  }
}
