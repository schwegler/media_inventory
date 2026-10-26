import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "button"]

  connect() {
    this.element.dataset.connected = "true"
    this.onKeydown = event => {
      if (event.key === "Escape" && this.element.classList.contains("search-open")) {
        this.close()
      }
    }
    this.onClick = event => {
      if (this.element.classList.contains("search-open") &&
          !this.panelTarget.contains(event.target) &&
          !this.buttonTarget.contains(event.target)) {
        this.close()
      }
    }
    this.onBeforeCache = () => this.close()
    this.onViewportChange = () => {
      if (this.positionFrame) return
      this.positionFrame = requestAnimationFrame(() => {
        this.positionFrame = null
        this.positionPanel()
      })
    }
    this.resizeObserver = new ResizeObserver(this.onViewportChange)
    this.resizeObserver.observe(this.element)
    this.resizeObserver.observe(this.buttonTarget)
    window.addEventListener("resize", this.onViewportChange)
    window.addEventListener("scroll", this.onViewportChange, { passive: true })
    document.addEventListener("keydown", this.onKeydown)
    document.addEventListener("click", this.onClick)
    document.addEventListener("turbo:before-cache", this.onBeforeCache)
  }

  disconnect() {
    this.resizeObserver.disconnect()
    window.removeEventListener("resize", this.onViewportChange)
    window.removeEventListener("scroll", this.onViewportChange)
    if (this.positionFrame) cancelAnimationFrame(this.positionFrame)
    this.positionFrame = null
    document.removeEventListener("keydown", this.onKeydown)
    document.removeEventListener("click", this.onClick)
    document.removeEventListener("turbo:before-cache", this.onBeforeCache)
  }

  toggle(event) {
    const open = this.element.classList.toggle("search-open")
    this.buttonTarget.setAttribute("aria-expanded", String(open))
    if (open) {
      this.opener = event?.currentTarget || document.activeElement
      this.positionPanel()
      this.panelTarget.querySelector("input")?.focus()
    } else {
      this.resetPosition()
      this.restoreFocus()
    }
  }

  close() {
    if (!this.element.classList.contains("search-open")) return
    this.element.classList.remove("search-open")
    this.buttonTarget.setAttribute("aria-expanded", "false")
    this.resetPosition()
    this.restoreFocus()
  }

  positionPanel() {
    if (!this.element.classList.contains("search-open")) return
    // At intermediate/mobile widths the same form becomes inline. Keep its
    // focus and query, but discard the popup state and coordinates.
    if (!this.buttonTarget.getClientRects().length) {
      this.element.classList.remove("search-open")
      this.buttonTarget.setAttribute("aria-expanded", "false")
      this.resetPosition()
      return
    }

    const button = this.buttonTarget.getBoundingClientRect()
    const panel = this.panelTarget
    const parent = panel.offsetParent
    const origin = parent.getBoundingClientRect()
    const gutter = 12
    const viewportWidth = document.documentElement.clientWidth
    panel.style.setProperty("--search-max-width", `${viewportWidth - gutter * 2}px`)
    const width = panel.getBoundingClientRect().width
    const left = Math.max(gutter, Math.min(button.right - width,
      viewportWidth - gutter - width))
    // Convert viewport bounds to the panel's existing positioned ancestor,
    // including the floating header's border and any ancestor scroll.
    panel.style.setProperty("--search-left", `${left - origin.left - parent.clientLeft + parent.scrollLeft}px`)
    panel.style.setProperty("--search-top", `${button.bottom + 8 - origin.top - parent.clientTop + parent.scrollTop}px`)
  }

  resetPosition() {
    this.panelTarget.style.removeProperty("--search-left")
    this.panelTarget.style.removeProperty("--search-top")
    this.panelTarget.style.removeProperty("--search-max-width")
  }

  restoreFocus() {
    if (this.opener && typeof this.opener.focus === "function") {
      this.opener.focus()
    } else if (this.hasButtonTarget) {
      this.buttonTarget.focus()
    }
  }
}
