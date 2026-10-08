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
        if (this.hasButtonTarget) this.buttonTarget.focus()
      }
    }
    this.onClick = (event) => {
      if (this.isOpen && !this.element.contains(event.target)) this.close()
    }
    this.onBeforeCache = () => this.close()
    document.addEventListener("keydown", this.onKeydown)
    document.addEventListener("click", this.onClick)
    document.addEventListener("turbo:before-cache", this.onBeforeCache)
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKeydown)
    document.removeEventListener("click", this.onClick)
    document.removeEventListener("turbo:before-cache", this.onBeforeCache)
  }

  toggle() {
    this.isOpen = !this.isOpen
    this.render()
  }

  close() {
    this.isOpen = false
    this.render()
  }

  render() {
    this.menuTarget.classList.toggle("active", this.isOpen)
    if (this.hasIconTarget) this.iconTarget.classList.toggle("hidden", this.isOpen)
    if (this.hasCloseIconTarget) this.closeIconTarget.classList.toggle("hidden", !this.isOpen)
    if (this.hasButtonTarget) this.buttonTarget.setAttribute("aria-expanded", String(this.isOpen))
  }
}
