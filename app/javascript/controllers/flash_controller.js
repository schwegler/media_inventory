import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="flash"
export default class extends Controller {
  static values = { dismissAfter: { type: Number, default: 3000 } }

  connect() {
    this.element.dataset.connected = "true"
    this.keydownHandler = (event) => {
      if (event.key === "Escape") {
        event.preventDefault()
        this.dismiss()
      }
    }
    this.element.addEventListener("keydown", this.keydownHandler)

    if (this.dismissAfterValue === 0) return
    this.timeout = setTimeout(() => {
      this.dismiss()
    }, this.dismissAfterValue)
  }

  disconnect() {
    if (this.keydownHandler) this.element.removeEventListener("keydown", this.keydownHandler)
    if (this.timeout) clearTimeout(this.timeout)
  }

  dismiss() {
    if (this.keydownHandler) {
      this.element.removeEventListener("keydown", this.keydownHandler)
      this.keydownHandler = null
    }
    if (typeof document !== "undefined" && this.element.contains(document.activeElement)) {
      document.getElementById("main-content")?.focus()
    }
    this.element.style.transition = "opacity 0.3s ease, transform 0.3s ease"
    this.element.style.opacity = "0"
    this.element.style.transform = "translateY(-10px)"
    setTimeout(() => this.element.remove(), 300)
  }
}
