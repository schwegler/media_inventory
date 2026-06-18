import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "menu", "button" ]

  connect() {
    this.clickOutsideHandler = this.clickOutside.bind(this)
    document.addEventListener("click", this.clickOutsideHandler)

    // Ensure dropdown is hidden on connection
    if (this.hasMenuTarget) {
      this.hide()
    }
    this.element.dataset.connected = "true"
  }

  disconnect() {
    document.removeEventListener("click", this.clickOutsideHandler)
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()
    const isVisible = this.menuTarget.style.display === "block"
    if (isVisible) {
      this.hide()
    } else {
      this.show()
    }
  }

  show() {
    this.menuTarget.style.display = "block"
    if (this.hasButtonTarget) {
      this.buttonTarget.setAttribute("aria-expanded", "true")
    }
  }

  hide() {
    this.menuTarget.style.display = "none"
    if (this.hasButtonTarget) {
      this.buttonTarget.setAttribute("aria-expanded", "false")
    }
  }

  clickOutside(event) {
    if (this.hasMenuTarget && !this.element.contains(event.target)) {
      this.hide()
    }
  }
}
