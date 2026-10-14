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
        this.opener?.focus()
      }
    }
    this.onClick = (event) => {
      if (this.isOpen && !this.element.contains(event.target)) this.close()
    }
    this.onBeforeCache = () => this.close()
    this.onResize = () => { if (window.innerWidth >= 1100) this.close() }
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
    this.opener = event.currentTarget
    this.isOpen = !this.isOpen
    this.render()
  }

  openSearch(event) {
    this.opener = event.currentTarget
    this.isOpen = true
    this.render()
    this.menuTarget.querySelector("input")?.focus()
  }

  navigate(event) {
    if (event.target.closest("a")) this.close()
  }

  close() {
    this.isOpen = false
    this.render()
  }

  render() {
    this.menuTarget.classList.toggle("active", this.isOpen)
    if (this.hasIconTarget) this.iconTarget.classList.toggle("hidden", this.isOpen)
    if (this.hasCloseIconTarget) this.closeIconTarget.classList.toggle("hidden", !this.isOpen)
    this.buttonTargets.forEach(button => button.setAttribute("aria-expanded", String(this.isOpen)))
  }
}
