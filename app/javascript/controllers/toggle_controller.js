import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="toggle"
export default class extends Controller {
  static targets = ["element"]
  static classes = ["hidden"]

  toggle(event) {
    event.preventDefault()
    this.elementTargets.forEach((el) => {
      el.classList.toggle(this.hiddenClass)
    })
  }

  hide(event) {
    event.preventDefault()
    this.elementTargets.forEach((el) => {
      el.classList.add(this.hiddenClass)
    })
  }
}
