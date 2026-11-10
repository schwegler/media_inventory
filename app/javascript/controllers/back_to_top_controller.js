import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.dataset.connected = "true"
    // Check initial scroll position immediately
    this.applyVisibility()
  }

  disconnect() {
    if (this.frame) {
      cancelAnimationFrame(this.frame)
      this.frame = null
    }
  }

  // Throttle scroll checks to requestAnimationFrame to prevent main thread thrashing
  // and redundant DOM mutations during high-frequency scroll events
  update() {
    if (this.frame) return
    this.frame = requestAnimationFrame(() => {
      this.frame = null
      this.applyVisibility()
    })
  }

  applyVisibility() {
    this.element.hidden = window.scrollY < 400
  }

  scrollToTop() {
    const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches ||
      document.documentElement.dataset.effects === "reduced"
    window.scrollTo({ top: 0, behavior: reducedMotion ? "instant" : "smooth" })
    document.getElementById("main-content")?.focus({ preventScroll: true })
  }
}
