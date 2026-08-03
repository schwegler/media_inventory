import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="toggle"
export default class extends Controller {
  static targets = ["element"]
  static classes = ["hidden"]

  connect() {
    this.element.dataset.connected = "true"
  }

  toggle(event) {
    if (event) {
      event.preventDefault()
    }
    let isVisibleNow = false
    this.elementTargets.forEach((el) => {
      el.classList.toggle(this.hiddenClass)
      if (!el.classList.contains(this.hiddenClass)) {
        isVisibleNow = true
      }
    })

    // Focus the first interactive element inside the newly visible target(s)
    if (isVisibleNow) {
      this.elementTargets.forEach((el) => {
        if (!el.classList.contains(this.hiddenClass)) {
          const interactive = el.querySelector("input, textarea, select")
          if (interactive) {
            interactive.focus()
          }
        }
      })
    }

    // Manage aria-expanded on the trigger button
    const trigger = this.element.querySelector("[aria-expanded]")
    if (trigger) {
      trigger.setAttribute("aria-expanded", isVisibleNow ? "true" : "false")
    }
  }

  hide(event) {
    if (event) {
      event.preventDefault()
    }
    this.elementTargets.forEach((el) => {
      el.classList.add(this.hiddenClass)
    })

    // Reset aria-expanded to false
    const trigger = this.element.querySelector("[aria-expanded]")
    if (trigger) {
      trigger.setAttribute("aria-expanded", "false")
    }
  }
}
