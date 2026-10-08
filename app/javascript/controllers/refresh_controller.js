import { Controller } from "@hotwired/stimulus"
export default class extends Controller {
  connect() {
    const panel = this.element.closest("[data-refresh-result=true]")
    if (panel) requestAnimationFrame(() => {
      panel.querySelector('[role="status"]')?.focus({ preventScroll: true })
      panel.scrollIntoView({ block: "center" })
    })
  }
  start() {
    this.element.setAttribute("aria-busy", "true")
    this.element.nextElementSibling.textContent = "Checking artwork and metadata…"
  }
  finish(event) {
    this.element.removeAttribute("aria-busy")
    if (!event.detail.success) this.element.nextElementSibling.textContent = "Unable to connect. Please try again."
  }
}
