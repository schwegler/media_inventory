import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="toggle"
export default class extends Controller {
  static targets = ["element"]
  static classes = ["hidden"]

  connect() {
    this.element.setAttribute("data-connected", "true")
  }

  toggle(event) {
    event.preventDefault()
    let isNowVisible = false

    this.elementTargets.forEach((el) => {
      el.classList.toggle(this.hiddenClass)
      // Check if the element is now visible
      if (!el.classList.contains(this.hiddenClass)) {
        isNowVisible = true
        // Automatically search for and focus the first visible interactive element inside the container
        const interactive = el.querySelector("input:not([type='hidden']), textarea, select")
        if (interactive) {
          interactive.focus()
        }
      }
    })

    // Update the aria-expanded attribute on the trigger button
    if (event && event.currentTarget) {
      event.currentTarget.setAttribute("aria-expanded", isNowVisible ? "true" : "false")
    }
  }

  hide(event) {
    event.preventDefault()
    this.elementTargets.forEach((el) => {
      el.classList.add(this.hiddenClass)
    })

    // Return focus to the trigger element that opened this form/element
    const activeTrigger = this.element.querySelector('[aria-expanded="true"]')
    if (activeTrigger) {
      activeTrigger.setAttribute("aria-expanded", "false")
      activeTrigger.focus()
    }
  }
}
