import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="flash"
export default class extends Controller {
  static values = { dismissAfter: { type: Number, default: 3000 } }

  connect() {
    if (this.dismissAfterValue === 0) return
    this.timeout = setTimeout(() => {
      this.dismiss()
    }, this.dismissAfterValue)
  }

  disconnect() {
    if (this.timeout) clearTimeout(this.timeout)
  }

  dismiss() {
    if (this.element.contains(document.activeElement)) document.getElementById("main-content")?.focus()
    this.element.style.transition = "opacity 0.3s ease, transform 0.3s ease"
    this.element.style.opacity = "0"
    this.element.style.transform = "translateY(-10px)"
    setTimeout(() => this.element.remove(), 300)
  }
}
