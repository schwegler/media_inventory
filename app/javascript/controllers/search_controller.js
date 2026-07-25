import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]

  connect() {
    this.keydownHandler = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this.keydownHandler)
    this.element.dataset.connected = "true"
  }

  disconnect() {
    document.removeEventListener("keydown", this.keydownHandler)
  }

  handleKeydown(event) {
    const target = event.target
    if (
      target.tagName === "INPUT" ||
      target.tagName === "TEXTAREA" ||
      target.tagName === "SELECT" ||
      target.isContentEditable
    ) {
      return
    }

    if (event.key === "/") {
      event.preventDefault()
      this.inputTarget.focus()
      this.inputTarget.select()
    }
  }

  toggle(event) {
    if (this.inputTarget.value.trim() === "" && document.activeElement !== this.inputTarget) {
      event.preventDefault()
      this.inputTarget.focus()
    }
  }
}
