import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "menu", "button" ]

  connect() {
    this.clickOutsideHandler = this.clickOutside.bind(this)
    document.addEventListener("click", this.clickOutsideHandler)
    
    // Ensure dropdown is hidden on connection
    if (this.hasMenuTarget) {
      this.menuTarget.style.display = "none"
    }
  }

  disconnect() {
    document.removeEventListener("click", this.clickOutsideHandler)
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()
    const isVisible = this.menuTarget.style.display === "block"
    this.setVisibility(!isVisible)
  }

  clickOutside(event) {
    if (this.hasMenuTarget && !this.element.contains(event.target)) {
      this.setVisibility(false)
    }
  }

  setVisibility(visible) {
    this.menuTarget.style.display = visible ? "block" : "none"
    if (this.hasButtonTarget) {
      this.buttonTarget.setAttribute("aria-expanded", visible ? "true" : "false")
    }
  }
}
