import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="flash"
export default class extends Controller {
  static values = { dismissAfter: { type: Number, default: 3000 } }

  connect() {
    this.pause = this.pause.bind(this)
    this.resume = this.resume.bind(this)

    this.element.addEventListener("mouseenter", this.pause)
    this.element.addEventListener("mouseleave", this.resume)
    this.element.addEventListener("focusin", this.pause)
    this.element.addEventListener("focusout", this.resume)

    this.startTimer()
    this.element.dataset.connected = "true"
  }

  disconnect() {
    this.clearTimer()
    this.element.removeEventListener("mouseenter", this.pause)
    this.element.removeEventListener("mouseleave", this.resume)
    this.element.removeEventListener("focusin", this.pause)
    this.element.removeEventListener("focusout", this.resume)
  }

  startTimer() {
    this.clearTimer()
    this.timeout = setTimeout(() => {
      this.dismiss()
    }, this.dismissAfterValue)
  }

  clearTimer() {
    if (this.timeout) {
      clearTimeout(this.timeout)
      this.timeout = null
    }
  }

  pause() {
    this.clearTimer()
  }

  resume() {
    this.startTimer()
  }

  dismiss() {
    this.element.style.transition = "opacity 0.3s ease, transform 0.3s ease"
    this.element.style.opacity = "0"
    this.element.style.transform = "translateY(-10px)"
    setTimeout(() => this.element.remove(), 300)
  }
}
