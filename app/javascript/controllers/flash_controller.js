import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="flash"
export default class extends Controller {
  static values = { dismissAfter: { type: Number, default: 3000 } }

  connect() {
    this.element.dataset.connected = "true"
    this.handlePause = this.clearTimer.bind(this)
    this.handleResume = this.startTimer.bind(this)

    this.element.addEventListener("mouseenter", this.handlePause)
    this.element.addEventListener("mouseleave", this.handleResume)
    this.element.addEventListener("focusin", this.handlePause)
    this.element.addEventListener("focusout", this.handleResume)

    this.startTimer()
  }

  disconnect() {
    this.clearTimer()
    this.element.removeEventListener("mouseenter", this.handlePause)
    this.element.removeEventListener("mouseleave", this.handleResume)
    this.element.removeEventListener("focusin", this.handlePause)
    this.element.removeEventListener("focusout", this.handleResume)
  }

  startTimer() {
    this.clearTimer()
    if (this.dismissAfterValue > 0) {
      this.timeout = setTimeout(() => {
        this.dismiss()
      }, this.dismissAfterValue)
    }
  }

  clearTimer() {
    if (this.timeout) {
      clearTimeout(this.timeout)
      this.timeout = null
    }
  }

  dismiss() {
    this.clearTimer()
    this.element.style.transition = "opacity 0.3s ease, transform 0.3s ease"
    this.element.style.opacity = "0"
    this.element.style.transform = "translateY(-10px)"
    setTimeout(() => {
      if (this.element && this.element.parentNode) {
        this.element.remove()
      }
    }, 300)
  }
}
