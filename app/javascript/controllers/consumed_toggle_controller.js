import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="consumed-toggle"
// Toggles visibility of consumed_at date field when consumed checkbox is changed
export default class extends Controller {
  static targets = ["checkbox", "dateRow"]

  connect() {
    this.toggle(false)
    this.element.dataset.connected = "true"
  }

  toggle(shouldFocus = true) {
    if (this.hasDateRowTarget && this.hasCheckboxTarget) {
      const isChecked = this.checkboxTarget.checked
      this.dateRowTarget.style.display = isChecked ? "block" : "none"
      this.checkboxTarget.setAttribute("aria-expanded", isChecked.toString())

      if (isChecked && shouldFocus) {
        const dateInput = this.dateRowTarget.querySelector("input")
        if (dateInput) {
          dateInput.focus()
        }
      }
    }
  }
}
