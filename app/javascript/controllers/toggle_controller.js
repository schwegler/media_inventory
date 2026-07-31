import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="toggle"
export default class extends Controller {
  static targets = ["element"]
  static classes = ["hidden"]

  toggle(event) {
    event.preventDefault()

    // Toggle aria-expanded on trigger if present
    const trigger = event.currentTarget
    if (trigger && trigger.hasAttribute("aria-expanded")) {
      const isExpanded = trigger.getAttribute("aria-expanded") === "true"
      trigger.setAttribute("aria-expanded", !isExpanded)
    }

    this.elementTargets.forEach((el) => {
      const wasHidden = el.classList.contains(this.hiddenClass)
      el.classList.toggle(this.hiddenClass)

      // Focus first visible interactive element (input, textarea, select) inside target
      if (wasHidden && !el.classList.contains(this.hiddenClass)) {
        const firstInteractive = el.querySelector("input:not([type='hidden']), textarea, select")
        if (firstInteractive) {
          firstInteractive.focus()
        }
      }
    })
  }

  hide(event) {
    event.preventDefault()

    // Reset aria-expanded on trigger if present
    const trigger = this.element.querySelector("[aria-expanded]")
    if (trigger) {
      trigger.setAttribute("aria-expanded", "false")
    }

    this.elementTargets.forEach((el) => {
      el.classList.add(this.hiddenClass)
    })
  }
}
