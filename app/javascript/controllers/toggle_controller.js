import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="toggle"
export default class extends Controller {
  static targets = ["element", "trigger"]
  static classes = ["hidden"]

  connect() {
    this.element.dataset.connected = "true"
  }

  toggle(event) {
    if (event) event.preventDefault()
    let isVisible = false
    this.elementTargets.forEach((el) => {
      el.classList.toggle(this.hiddenClass)
      if (!el.classList.contains(this.hiddenClass)) {
        isVisible = true
      }
    })

    // Update aria-expanded on trigger button
    if (this.hasTriggerTarget) {
      this.triggerTarget.setAttribute("aria-expanded", isVisible ? "true" : "false")
    } else if (event && event.currentTarget) {
      event.currentTarget.setAttribute("aria-expanded", isVisible ? "true" : "false")
    }

    // Focus first visible interactive element if opened
    if (isVisible) {
      this.focusFirstInteractive()
    }
  }

  hide(event) {
    if (event) event.preventDefault()
    this.elementTargets.forEach((el) => {
      el.classList.add(this.hiddenClass)
    })

    if (this.hasTriggerTarget) {
      this.triggerTarget.setAttribute("aria-expanded", "false")
      this.triggerTarget.focus()
    } else if (event && event.currentTarget) {
      event.currentTarget.setAttribute("aria-expanded", "false")
    }
  }

  focusFirstInteractive() {
    for (const el of this.elementTargets) {
      if (!el.classList.contains(this.hiddenClass)) {
        const interactive = el.querySelector("input:not([type=hidden]), textarea, select, button")
        if (interactive) {
          interactive.focus()
          break
        }
      }
    }
  }
}
