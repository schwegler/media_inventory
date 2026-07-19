import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="toggle"
export default class extends Controller {
  static targets = ["element"]
  static classes = ["hidden"]

  toggle(event) {
    event.preventDefault()
    this.elementTargets.forEach((el) => {
      el.classList.toggle(this.hiddenClass)
      const isVisible = !el.classList.contains(this.hiddenClass)
      if (isVisible) {
        const input = el.querySelector("input:not([type='hidden']), textarea, select")
        if (input) {
          setTimeout(() => input.focus(), 50)
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
