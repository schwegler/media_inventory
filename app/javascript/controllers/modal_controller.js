import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["overlay"]

  connect() {
    this.element.dataset.connected = "true"

    // If the frame has content (modal loaded), show the overlay
    if (this.element.innerHTML.trim()) {
      document.body.style.overflow = "hidden"
      this.previousActiveElement = document.activeElement
      this.focusFirstElement()
    }
  }

  disconnect() {
    document.body.style.overflow = ""
    this.restoreFocus()
  }

  close(event) {
    if (event) event.preventDefault()
    // Clear the turbo frame to dismiss the modal
    const frame = document.querySelector("turbo-frame#modal")
    if (frame) {
      frame.innerHTML = ""
      frame.removeAttribute("src")
    }
    document.body.style.overflow = ""
    this.restoreFocus()
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
      const focusable = this.element.querySelector("input:not([type='hidden']), textarea, select, button")
      if (focusable) focusable.focus()
    }, 50)
  }

  restoreFocus() {
    if (this.previousActiveElement && typeof this.previousActiveElement.focus === "function") {
      this.previousActiveElement.focus()
      this.previousActiveElement = null
    }
  }
}
