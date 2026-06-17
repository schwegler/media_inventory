import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["overlay"]

  connect() {
    // If the frame has content (modal loaded), show the overlay
    if (this.element.innerHTML.trim()) {
      document.body.style.overflow = "hidden"
    }
  }

  disconnect() {
    document.body.style.overflow = ""
  }

  close(event) {
    event.preventDefault()
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
}
