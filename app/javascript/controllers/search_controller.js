import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]

  connect() {
    this.keydownHandler = this.keydown.bind(this)
    document.addEventListener("keydown", this.keydownHandler)
  }

  disconnect() {
    document.removeEventListener("keydown", this.keydownHandler)
  }

  toggle(event) {
    if (this.inputTarget.value.trim() === "" && document.activeElement !== this.inputTarget) {
      event.preventDefault()
      this.inputTarget.focus()
    }
  }

  keydown(event) {
    if (event.key === "/" && !["INPUT", "TEXTAREA", "SELECT"].includes(document.activeElement.tagName)) {
      const isVisible = !!(this.inputTarget.offsetWidth || this.inputTarget.offsetHeight || this.inputTarget.getClientRects().length)
      if (isVisible) {
        event.preventDefault()
        this.inputTarget.focus()
      }
    }
  }
}
