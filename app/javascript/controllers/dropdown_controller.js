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
    if (!this.hasMenuTarget) return

    const isVisible = this.menuTarget.style.display === "block"
    const isInside = this.element.contains(document.activeElement)

    if (event.key === "Escape" && isVisible) {
      this.hide()
      if (this.hasButtonTarget) {
        this.buttonTarget.focus()
      }
      event.preventDefault()
      return
    }

    if (!isInside) return

    const items = Array.from(this.menuTarget.querySelectorAll(".dropdown-item"))
    if (items.length === 0) return

    const currentIndex = items.indexOf(document.activeElement)

    if (event.key === "ArrowDown") {
      event.preventDefault()
      if (!isVisible) {
        this.show()
        items[0].focus()
      } else if (currentIndex === -1) {
        items[0].focus()
      } else {
        const nextIndex = (currentIndex + 1) % items.length
        items[nextIndex].focus()
      }
    } else if (event.key === "ArrowUp") {
      event.preventDefault()
      if (!isVisible) {
        this.show()
        items[items.length - 1].focus()
      } else if (currentIndex === -1) {
        items[items.length - 1].focus()
      } else {
        const prevIndex = (currentIndex - 1 + items.length) % items.length
        items[prevIndex].focus()
      }
    } else if (event.key === "Home" && isVisible && currentIndex !== -1) {
      event.preventDefault()
      items[0].focus()
    } else if (event.key === "End" && isVisible && currentIndex !== -1) {
      event.preventDefault()
      items[items.length - 1].focus()
    }
  }
}
