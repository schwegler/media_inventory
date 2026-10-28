import { Controller } from "@hotwired/stimulus"

// Native details remains usable without JS. Add familiar dismissal for floating menus.
export default class extends Controller {
  static values = { closeOnSelect: { type: Boolean, default: true } }

  connect() {
    this.element.dataset.connected = "true"
    this.dismissOutside = event => {
      if (!this.element.contains(event.target)) this.element.open = false
    }
    this.dismissEscape = event => {
      if (event.key !== "Escape" || !this.element.open) return
      event.preventDefault()
      this.element.open = false
      this.element.querySelector("summary")?.focus()
    }
    this.clickInside = event => {
      const item = event.target.closest?.("a, button, [role='menuitem'], .dropdown-item")
      if (this.closeOnSelectValue && item && !this.element.querySelector("summary")?.contains(item)) {
        this.element.open = false
      }
    }
    this.beforeCache = () => { this.element.open = false }
    document.addEventListener("turbo:before-cache", this.beforeCache)
    document.addEventListener("pointerdown", this.dismissOutside)
    this.element.addEventListener("keydown", this.dismissEscape)
    this.element.addEventListener("click", this.clickInside)
  }

  disconnect() {
    document.removeEventListener("turbo:before-cache", this.beforeCache)
    document.removeEventListener("pointerdown", this.dismissOutside)
    this.element.removeEventListener("keydown", this.dismissEscape)
    this.element.removeEventListener("click", this.clickInside)
  }
}
