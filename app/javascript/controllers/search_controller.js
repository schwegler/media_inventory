import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]

  connect() {
    this.keydownHandler = this.handleKeydown.bind(this)
    window.addEventListener("keydown", this.keydownHandler)
    this.element.dataset.connected = "true"
  }

  disconnect() {
    window.removeEventListener("keydown", this.keydownHandler)
  }

  handleKeydown(event) {
    const active = document.activeElement
    if (event.key === "/" && active && !active.isContentEditable && !["INPUT", "TEXTAREA", "SELECT"].includes(active.tagName)) {
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
