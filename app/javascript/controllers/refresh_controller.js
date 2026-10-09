import { Turbo } from "@hotwired/turbo-rails"
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.onLoad = () => this.sync()
    document.addEventListener("turbo:load", this.onLoad)
    this.sync()
  }

  disconnect() {
    clearTimeout(this.pollTimer)
    document.removeEventListener("turbo:load", this.onLoad)
  }

  sync() {
    clearTimeout(this.pollTimer)
    const panel = this.element.closest("#metadata-health")
    if (panel?.dataset.refreshResult === "true") {
      panel.querySelector('[role="status"]')?.focus({ preventScroll: true })
      panel.scrollIntoView({ block: "center" })
    }
    if (panel?.dataset.refreshState === "refreshing") {
      this.pollTimer = setTimeout(() => Turbo.visit(window.location.href, { action: "replace" }), 2000)
    }
  }

  start() {
    this.element.setAttribute("aria-busy", "true")
    this.element.nextElementSibling.textContent = "Checking artwork and metadata…"
  }

  finish(event) {
    this.element.removeAttribute("aria-busy")
    if (event.detail.success) this.sync()
    else this.element.nextElementSibling.textContent = "Unable to connect. Please try again."
  }
}
