import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="mobile-menu"
export default class extends Controller {
  static targets = ["menu", "icon", "closeIcon", "button"]

  connect() {
    this.isOpen = false
    this.element.dataset.connected = "true"
    this.keydownHandler = this.keydown.bind(this)
    document.addEventListener("keydown", this.keydownHandler)
  }

  toggle() {
    this.isOpen = !this.isOpen

    if (this.isOpen) {
      this.menuTarget.classList.add("active")
      if (this.hasIconTarget) this.iconTarget.classList.add("hidden")
      if (this.hasCloseIconTarget) this.closeIconTarget.classList.remove("hidden")
    } else {
      this.menuTarget.classList.remove("active")
      if (this.hasIconTarget) this.iconTarget.classList.remove("hidden")
      if (this.hasCloseIconTarget) this.closeIconTarget.classList.add("hidden")
    }

    if (this.hasButtonTarget) {
      this.buttonTarget.setAttribute("aria-expanded", this.isOpen ? "true" : "false")
    }
  }

  keydown(event) {
    if (event.key === "Escape" && this.isOpen) {
      this.toggle()
      if (this.hasButtonTarget) {
        this.buttonTarget.focus()
      }
    }
  }

  disconnect() {
    document.removeEventListener("keydown", this.keydownHandler)
  }
}
