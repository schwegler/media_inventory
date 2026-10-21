import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["status", "error"]

  start() {
    this.element.setAttribute("aria-busy", "true")
    this.statusTarget.textContent = "Updating your dashboard…"
    this.errorTarget.hidden = true
  }

  finish(event) {
    this.element.removeAttribute("aria-busy")
    this.statusTarget.textContent = ""
    if (!event.detail.success) this.error()
  }

  error() {
    this.element.removeAttribute("aria-busy")
    this.statusTarget.textContent = ""
    this.errorTarget.hidden = false
    this.errorTarget.textContent = "Could not update tracking. Check your connection and try again."
  }
}
