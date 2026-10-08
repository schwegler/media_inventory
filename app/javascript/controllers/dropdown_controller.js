import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "menu", "button" ]

  connect() {
    this.clickOutsideHandler = this.clickOutside.bind(this)
    this.keydownHandler = this.keydown.bind(this)
    document.addEventListener("click", this.clickOutsideHandler)
    document.addEventListener("keydown", this.keydownHandler)

    // Ensure dropdown is hidden on connection
    if (this.hasMenuTarget) {
      this.hide()
    }
    this.element.dataset.connected = "true"
  }

  disconnect() {
    document.removeEventListener("click", this.clickOutsideHandler)
    document.removeEventListener("keydown", this.keydownHandler)
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()
    const isVisible = this.menuTarget.style.display === "block"
    if (isVisible) {
      this.hide()
    } else {
      this.show()
    }
  }

  show() {
    this.menuTarget.style.display = "block"
    this.menuTarget.querySelector('[role="menuitem"]')?.focus()
    if (this.hasButtonTarget) {
      this.buttonTarget.setAttribute("aria-expanded", "true")
    }
  }

  hide() {
    this.menuTarget.style.display = "none"
    if (this.hasButtonTarget) {
      this.buttonTarget.setAttribute("aria-expanded", "false")
    }
  }

  clickOutside(event) {
    if (this.hasMenuTarget && !this.element.contains(event.target)) {
      this.hide()
    }
  }

  keydown(event) {
    const visible = this.menuTarget.style.display === "block"
    if (event.target === this.buttonTarget && ["ArrowDown", "ArrowUp"].includes(event.key) && !visible) {
      event.preventDefault()
      this.show()
      if (event.key === "ArrowUp") this.menuTarget.querySelector('[role="menuitem"]:last-child')?.focus()
      return
    }
    if (visible && event.key === "Tab") {
      this.hide()
      this.buttonTarget.focus()
      return
    }
    if (this.menuTarget.style.display === "block" && ["ArrowDown", "ArrowUp", "Home", "End"].includes(event.key)) {
      event.preventDefault()
      const items = [...this.menuTarget.querySelectorAll('[role="menuitem"]')]
      const index = items.indexOf(document.activeElement)
      const next = event.key === "Home" ? 0 : event.key === "End" ? items.length - 1 : (index + (event.key === "ArrowDown" ? 1 : -1) + items.length) % items.length
      items[next]?.focus()
    }
    if (event.key === "Escape" && this.hasMenuTarget) {
      const isVisible = this.menuTarget.style.display === "block"
      if (isVisible) {
        this.hide()
        if (this.hasButtonTarget) {
          this.buttonTarget.focus()
        }
      }
    }
  }
}
