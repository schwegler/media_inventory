import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="toggle"
export default class extends Controller {
  static targets = ["element"]
  static classes = ["hidden"]

  connect() {
    this.element.dataset.connected = "true"
  }

  toggle(event) {
    if (event) event.preventDefault()
    const hiddenClass = this.hasHiddenClass ? this.hiddenClass : "hidden"

    this.elementTargets.forEach((el) => {
      const isHiddenBefore = el.classList.contains(hiddenClass)
      el.classList.toggle(hiddenClass)
      const isHiddenAfter = el.classList.contains(hiddenClass)

      // If it is now visible, search for the first visible interactive element and focus it
      if (isHiddenBefore && !isHiddenAfter) {
        const focusable = el.querySelector('input:not([type="hidden"]):not([disabled]), textarea:not([disabled]), select:not([disabled])')
        if (focusable) {
          // A tiny timeout to ensure rendering/animation is complete and element is fully interactable
          setTimeout(() => focusable.focus(), 50)
        }
      }
    })
  }

  hide(event) {
    if (event) event.preventDefault()
    const hiddenClass = this.hasHiddenClass ? this.hiddenClass : "hidden"

    this.elementTargets.forEach((el) => {
      el.classList.add(hiddenClass)
    })
  }
}
