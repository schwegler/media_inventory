import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]

  connect() {
    this.boundKeydown = this.handleKeydown.bind(this)
    window.addEventListener("keydown", this.boundKeydown)
    this.element.dataset.connected = "true"
  }

  disconnect() {
    window.removeEventListener("keydown", this.boundKeydown)
  }

  handleKeydown(event) {
    if (event.key === "/" && !["INPUT", "TEXTAREA", "SELECT"].includes(document.activeElement.tagName) && !document.activeElement.isContentEditable) {
      event.preventDefault()
      this.inputTarget.focus()
    }
  }

  toggle(event) {
    if (this.inputTarget.value.trim() === "" && document.activeElement !== this.inputTarget) {
      event.preventDefault()
      this.inputTarget.focus()
    }
  }
}
