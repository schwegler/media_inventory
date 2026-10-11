import { Turbo } from "@hotwired/turbo-rails"
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.pollCount = 0
    this.sync()
  }

  disconnect() {
    clearTimeout(this.pollTimer)
  }

  sync() {
    clearTimeout(this.pollTimer)
    const panel = this.element.closest("#metadata-health")
    if (!panel) return

    if (panel.dataset.refreshResult === "true") {
      panel.querySelector('[role="status"]')?.focus({ preventScroll: true })
      panel.scrollIntoView({ block: "center" })
    }

    // Only poll if the user explicitly requested a refresh (panel has refreshResult="true")
    // Do NOT poll on general page visits when the user is simply interacting with their library.
    if (panel.dataset.refreshResult === "true" && panel.dataset.refreshState === "refreshing") {
      if (this.pollCount >= 10) {
        const statusEl = panel.querySelector('[role="status"]') || panel.querySelector(".refresh-status")
        if (statusEl) statusEl.textContent = "Metadata check is taking longer than expected. Please check back later."
        return
      }

      this.pollCount++
      this.pollTimer = setTimeout(() => {
        Turbo.visit(window.location.href, { action: "replace" })
      }, 2000)
    }
  }

  start() {
    this.element.setAttribute("aria-busy", "true")
    const statusEl = this.element.nextElementSibling
    if (statusEl) statusEl.textContent = "Checking artwork and metadata…"
  }

  finish(event) {
    this.element.removeAttribute("aria-busy")
    if (event.detail.success) {
      this.pollCount = 0
      this.sync()
    } else {
      const statusEl = this.element.nextElementSibling
      if (statusEl) statusEl.textContent = "Unable to connect. Please try again."
    }
  }
}
