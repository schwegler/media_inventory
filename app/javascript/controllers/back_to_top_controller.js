import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.update()
  }

  update() {
    this.element.hidden = window.scrollY < 400
  }

  scrollToTop() {
    const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches ||
      document.documentElement.dataset.effects === "reduced"
    window.scrollTo({ top: 0, behavior: reducedMotion ? "instant" : "smooth" })
    document.getElementById("main-content")?.focus({ preventScroll: true })
  }
}
