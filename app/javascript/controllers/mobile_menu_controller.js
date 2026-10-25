import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "icon", "closeIcon", "button"]

  connect() {
    this.isOpen = false
    this.render()
    this.element.dataset.connected = "true"
    this.onKeydown = (event) => {
      if (event.key === "Escape" && this.isOpen) {
        this.close()
      }
    }
    this.onClick = (event) => {
      if (this.isOpen && !this.element.contains(event.target)) this.close()
    }
    this.onBeforeCache = () => this.close({ restoreFocus: false })
    this.onResize = () => { if (window.innerWidth >= 1100) this.close({ restoreFocus: false }) }
    window.addEventListener("resize", this.onResize)
    document.addEventListener("keydown", this.onKeydown)
    document.addEventListener("click", this.onClick)
    document.addEventListener("turbo:before-cache", this.onBeforeCache)
  }

  disconnect() {
    window.removeEventListener("resize", this.onResize)
    document.removeEventListener("keydown", this.onKeydown)
    document.removeEventListener("click", this.onClick)
    document.removeEventListener("turbo:before-cache", this.onBeforeCache)
  }

  toggle(event) {
    if (event?.currentTarget) this.opener = event.currentTarget
    if (this.isOpen) {
      this.close()
    } else {
      this.isOpen = true
      this.render()
    }
  }

  openSearch(event) {
    if (event?.currentTarget) this.opener = event.currentTarget
    this.isOpen = true
    this.render()
    this.menuTarget.querySelector("input")?.focus()
  }

  navigate(event) {
    if (event.target.closest("a")) this.close({ restoreFocus: false })
  }

  close(options = {}) {
    const wasOpen = this.isOpen
    this.isOpen = false
    this.render()
    if (wasOpen && options.restoreFocus !== false) {
      const opener = this.opener || (this.hasButtonTarget ? this.buttonTarget : null)
      opener?.focus()
    }
    this.opener = null
  }

  render() {
    this.menuTarget.classList.toggle("active", this.isOpen)
    if (this.hasIconTarget) this.iconTarget.classList.toggle("hidden", this.isOpen)
    if (this.hasCloseIconTarget) this.closeIconTarget.classList.toggle("hidden", !this.isOpen)
    this.buttonTargets.forEach(button => button.setAttribute("aria-expanded", String(this.isOpen)))
  }
}
