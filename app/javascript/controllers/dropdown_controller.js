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
    if (this.hasButtonTarget) {
      this.buttonTarget.setAttribute("aria-expanded", "true")
    }
    const menuItems = this.getMenuItems()
    if (menuItems.length > 0) {
      menuItems[0].focus()
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

  getMenuItems() {
    if (!this.hasMenuTarget) return []
    return Array.from(this.menuTarget.querySelectorAll("a, button, [tabindex]:not([tabindex='-1'])"))
  }

  keydown(event) {
    if (!this.hasMenuTarget) return
    const isVisible = this.menuTarget.style.display === "block"
    if (!isVisible) return

    if (event.key === "Escape") {
      this.hide()
      if (this.hasButtonTarget) {
        this.buttonTarget.focus()
      }
      return
    }

    const items = this.getMenuItems()
    if (items.length === 0) return

    const currentIndex = items.indexOf(document.activeElement)

    if (event.key === "ArrowDown") {
      event.preventDefault()
      const nextIndex = currentIndex < items.length - 1 ? currentIndex + 1 : 0
      items[nextIndex].focus()
    } else if (event.key === "ArrowUp") {
      event.preventDefault()
      const prevIndex = currentIndex > 0 ? currentIndex - 1 : items.length - 1
      items[prevIndex].focus()
    } else if (event.key === "Home") {
      event.preventDefault()
      items[0].focus()
    } else if (event.key === "End") {
      event.preventDefault()
      items[items.length - 1].focus()
    } else if (event.key === "Tab") {
      this.hide()
    }
  }
}
