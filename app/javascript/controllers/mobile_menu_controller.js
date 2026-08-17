import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="mobile-menu"
export default class extends Controller {
  static targets = ["menu", "button", "icon", "closeIcon"]

  connect() {
    this.isOpen = false
    this.keydownHandler = this.keydown.bind(this)
    document.addEventListener("keydown", this.keydownHandler)
    this.element.dataset.connected = "true"
  }

  disconnect() {
    document.removeEventListener("keydown", this.keydownHandler)
  }

  toggle() {
    this.isOpen = !this.isOpen
    
    if (this.isOpen) {
      this.open()
    } else {
      this.close()
    }
  }

  open() {
    this.isOpen = true
    this.menuTarget.classList.add("active")
    if (this.hasIconTarget) this.iconTarget.classList.add("hidden")
    if (this.hasCloseIconTarget) this.closeIconTarget.classList.remove("hidden")
    if (this.hasButtonTarget) this.buttonTarget.setAttribute("aria-expanded", "true")
  }

  close() {
    this.isOpen = false
    this.menuTarget.classList.remove("active")
    if (this.hasIconTarget) this.iconTarget.classList.remove("hidden")
    if (this.hasCloseIconTarget) this.closeIconTarget.classList.add("hidden")
    if (this.hasButtonTarget) this.buttonTarget.setAttribute("aria-expanded", "false")
  }

  keydown(event) {
    if (event.key === "Escape" && this.isOpen) {
      this.close()
      if (this.hasButtonTarget) {
        this.buttonTarget.focus()
      }
    }
  }
}
