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

  toggle(event) {
    if (this.inputTarget.value.trim() === "" && document.activeElement !== this.inputTarget) {
      event.preventDefault()
      this.inputTarget.focus()
    }
  }

  handleKeydown(event) {
    if (event.key === "/") {
      const active = document.activeElement
      if (active) {
        const isInput = active.tagName === "INPUT" ||
                        active.tagName === "TEXTAREA" ||
                        active.tagName === "SELECT" ||
                        active.isContentEditable
        if (isInput) return
      }
      event.preventDefault()
      this.inputTarget.focus()
      const form = this.inputTarget.closest(".global-search-form")
      if (form && !form.classList.contains("active")) {
        form.classList.add("active")
      }
    }
  }
}
