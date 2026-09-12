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

  disconnect() {
    document.removeEventListener("keydown", this.keydownHandler)
  }

  toggle(event) {
    if (event) event.preventDefault()
    this.isOpen = !this.isOpen

    if (this.isOpen) {
      this.menuTarget.classList.add("active")
      if (this.hasIconTarget) this.iconTarget.classList.add("hidden")
      if (this.hasCloseIconTarget) this.closeIconTarget.classList.remove("hidden")
      if (this.hasButtonTarget) this.buttonTarget.setAttribute("aria-expanded", "true")
    } else {
      this.closeMenu()
    }
  }

  closeMenu() {
    this.isOpen = false
    this.menuTarget.classList.remove("active")
    if (this.hasIconTarget) this.iconTarget.classList.remove("hidden")
    if (this.hasCloseIconTarget) this.closeIconTarget.classList.add("hidden")
    if (this.hasButtonTarget) this.buttonTarget.setAttribute("aria-expanded", "false")
  }

  keydown(event) {
    if (event.key === "Escape" && this.isOpen) {
      this.closeMenu()
      if (this.hasButtonTarget) this.buttonTarget.focus()
    }
  }
}
