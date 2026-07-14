import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]

  connect() {
    this.boundKeydown = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this.boundKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundKeydown)
  }

  toggle(event) {
    if (this.inputTarget.value.trim() === "" && document.activeElement !== this.inputTarget) {
      event.preventDefault()
      this.inputTarget.focus()
    }
  }

  handleKeydown(event) {
    // Only trigger if '/' is pressed and not already in an input/textarea/select
    if (event.key === "/" && !["INPUT", "TEXTAREA", "SELECT"].includes(document.activeElement.tagName)) {
      event.preventDefault()
      this.inputTarget.focus()
    }
  }
}
