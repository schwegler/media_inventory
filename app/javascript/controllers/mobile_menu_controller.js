import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="mobile-menu"
export default class extends Controller {
  static targets = ["menu", "icon", "closeIcon"]

  connect() {
    this.isOpen = false
  }

  toggle() {
    this.isOpen = !this.isOpen
    
    if (this.isOpen) {
      this.menuTarget.classList.add("active")
      if (this.hasIconTarget) this.iconTarget.classList.add("hidden")
      if (this.hasCloseIconTarget) this.closeIconTarget.classList.remove("hidden")
      document.body.style.overflow = "hidden" // Prevent scrolling when menu is open
    } else {
      this.menuTarget.classList.remove("active")
      if (this.hasIconTarget) this.iconTarget.classList.remove("hidden")
      if (this.hasCloseIconTarget) this.closeIconTarget.classList.add("hidden")
      document.body.style.overflow = ""
    }
  }
}
