import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["header"]

  connect() {
    this.measure()
    this.onScroll = () => {
      if (this.frame) return
      this.frame = requestAnimationFrame(() => {
        this.frame = null
        this.update()
      })
    }
    this.onResize = () => { this.measure(); this.update() }
    this.onBeforeCache = () => this.restore()
    window.addEventListener("scroll", this.onScroll, { passive: true })
    window.addEventListener("resize", this.onResize)
    document.addEventListener("turbo:before-cache", this.onBeforeCache)
    this.update()
    this.element.dataset.connected = "true"
  }

  disconnect() {
    window.removeEventListener("scroll", this.onScroll)
    window.removeEventListener("resize", this.onResize)
    document.removeEventListener("turbo:before-cache", this.onBeforeCache)
    if (this.frame) cancelAnimationFrame(this.frame)
  }

  measure() {
    this.restore()
    this.height = this.element.getBoundingClientRect().height
    this.threshold = this.height + 24
  }

  update() {
    const compact = window.scrollY > this.threshold
    this.element.style.height = compact ? `${this.height}px` : ""
    this.headerTarget.classList.toggle("combined-header", compact)
    const focused = document.activeElement
    if (compact && this.headerTarget.contains(focused) && focused.getClientRects().length === 0) {
      this.headerTarget.querySelector(".mobile-menu-btn")?.focus({ preventScroll: true })
    }
  }

  restore() {
    this.headerTarget.classList.remove("combined-header")
    this.element.style.height = ""
  }
}
