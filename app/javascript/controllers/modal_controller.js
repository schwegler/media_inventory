import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["overlay"]

  connect() {
    this.element.dataset.connected = "true"
    this.previousActiveElement = document.activeElement

    // If the frame has content (modal loaded), show the overlay
    if (this.element.innerHTML.trim()) {
      document.body.style.overflow = "hidden"
      this.focusFirstElement()
    }
  }

  disconnect() {
    document.body.style.overflow = ""
    this.restoreFocus()
  }

  close(event) {
    if (event) event.preventDefault()
    this.restoreFocus()
    // Clear the turbo frame to dismiss the modal
    const frame = document.querySelector("turbo-frame#modal")
    if (frame) {
      frame.innerHTML = ""
      frame.removeAttribute("src")
    }
    document.body.style.overflow = ""
  }

  closeOnBackdrop(event) {
    // Only close if clicking the overlay itself, not the modal content
    if (event.target === this.overlayTarget) {
      this.close(event)
    }
  }

  closeOnEsc(event) {
    if (event.key === "Escape") {
      this.close(event)
    }
  }

  focusFirstElement() {
    setTimeout(() => {
      const focusable = this.element.querySelector(
        "input:not([type='hidden']), textarea, select, button, [tabindex]:not([tabindex='-1'])"
      )
      if (focusable && typeof focusable.focus === "function") {
        focusable.focus()
      }
    }, 50)
  }

  restoreFocus() {
    if (this.previousActiveElement && typeof this.previousActiveElement.focus === "function") {
      this.previousActiveElement.focus()
      this.previousActiveElement = null
    }
  }
}
