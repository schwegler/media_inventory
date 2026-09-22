import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]

  connect() {
    this.element.dataset.connected = "true"
  }

  toggle(event) {
    if (this.inputTarget.value.trim() === "" && document.activeElement !== this.inputTarget) {
      event.preventDefault()
      this.inputTarget.focus()
    }
  }

  clearOrBlur(event) {
    if (event.key === "Escape") {
      this.inputTarget.blur()
    }
  }
}
