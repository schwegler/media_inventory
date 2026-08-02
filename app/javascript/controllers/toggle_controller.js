import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="toggle"
export default class extends Controller {
  static targets = ["element"]
  static classes = ["hidden"]

  connect() {
    this.element.dataset.connected = "true"
  }

  toggle(event) {
    event.preventDefault()
    this.elementTargets.forEach((el) => {
      const wasHidden = el.classList.contains(this.hiddenClass)
      el.classList.toggle(this.hiddenClass)
      const isVisible = !el.classList.contains(this.hiddenClass)

      if (wasHidden && isVisible) {
        // Find first visible interactive element and focus it
        const firstInput = el.querySelector("input:not([type='hidden']), textarea, select")
        if (firstInput) {
          // Wrap in requestAnimationFrame to ensure element is painted and focusable
          requestAnimationFrame(() => {
            firstInput.focus()
          })
        }
      }
    })
  }

  hide(event) {
    event.preventDefault()
    this.elementTargets.forEach((el) => {
      el.classList.add(this.hiddenClass)
    })
  }
}
