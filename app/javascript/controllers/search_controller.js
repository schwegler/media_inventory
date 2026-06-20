import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]

  toggle(event) {
    if (this.inputTarget.value.trim() === "" && document.activeElement !== this.inputTarget) {
      event.preventDefault()
      this.inputTarget.focus()
    }
  }
}
