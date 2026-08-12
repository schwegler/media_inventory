import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="toggle"
export default class extends Controller {
  static targets = ["element", "trigger"]
  static classes = ["hidden"]

  toggle(event) {
    if (event) event.preventDefault()

    this.elementTargets.forEach((el) => {
      const isCurrentlyHidden = el.classList.contains(this.hiddenClass)
      el.classList.toggle(this.hiddenClass)

      if (isCurrentlyHidden) {
        // We just showed it! Manage focus flow and ARIA states
        if (this.hasTriggerTarget) {
          this.triggerTarget.setAttribute("aria-expanded", "true")
        }
        const input = el.querySelector("input:not([type='hidden']), textarea")
        if (input) {
          setTimeout(() => input.focus(), 50)
        }
      } else {
        // We just hid it! Manage focus flow and ARIA states
        if (this.hasTriggerTarget) {
          this.triggerTarget.setAttribute("aria-expanded", "false")
          setTimeout(() => this.triggerTarget.focus(), 50)
        }
      }
    })
  }

  hide(event) {
    if (event) event.preventDefault()

    this.elementTargets.forEach((el) => {
      el.classList.add(this.hiddenClass)
    })

    if (this.hasTriggerTarget) {
      this.triggerTarget.setAttribute("aria-expanded", "false")
      setTimeout(() => this.triggerTarget.focus(), 50)
    }
  }
}
