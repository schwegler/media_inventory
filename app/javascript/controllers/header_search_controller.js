import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "button"]

  connect() {
    this.onKeydown = event => {
      if (event.key === "Escape" && this.element.classList.contains("search-open")) {
        this.close()
        this.buttonTarget.focus()
      }
    }
    this.onClick = event => {
      if (!this.panelTarget.contains(event.target) && !this.buttonTarget.contains(event.target)) this.close()
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
    const open = this.element.classList.toggle("search-open")
    this.buttonTarget.setAttribute("aria-expanded", String(open))
    if (open) this.panelTarget.querySelector("input")?.focus()
  }

  close() {
    this.element.classList.remove("search-open")
    this.buttonTarget.setAttribute("aria-expanded", "false")
  }
}
