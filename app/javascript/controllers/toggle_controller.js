import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="toggle"
export default class extends Controller {
  static targets = ["element"]
  static classes = ["hidden"]

  toggle(event) {
    event.preventDefault()
    const trigger = event.currentTarget

    this.elementTargets.forEach((el) => {
      el.classList.toggle(this.hiddenClass)
      const isVisibleAfter = !el.classList.contains(this.hiddenClass)

      if (trigger) {
        trigger.setAttribute("aria-expanded", isVisibleAfter ? "true" : "false")
      }

      if (isVisibleAfter) {
        const interactive = el.querySelector("input:not([type='hidden']), textarea, select, button:not([disabled])")
        if (interactive) {
          setTimeout(() => interactive.focus(), 50)
        }
      } else {
        if (trigger) {
          trigger.focus()
        }
      }
    })
  }

  hide(event) {
    event.preventDefault()
    this.elementTargets.forEach((el) => {
      el.classList.add(this.hiddenClass)
    })

    const triggers = this.element.querySelectorAll("[aria-expanded]")
    triggers.forEach((trigger) => {
      trigger.setAttribute("aria-expanded", "false")
    })

    const replyBtn = this.element.querySelector(".btn-reply") || this.element.querySelector("[aria-expanded]")
    if (replyBtn) {
      replyBtn.focus()
    }
  }
}
