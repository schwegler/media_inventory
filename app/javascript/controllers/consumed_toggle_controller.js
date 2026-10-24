import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="consumed-toggle"
// Toggles visibility of consumed_at date field when consumed checkbox is changed
export default class extends Controller {
  static targets = ["checkbox", "dateRow"]

  connect() {
    this.element.dataset.connected = "true"
    this.toggle()
  }

  toggle(event) {
    if (this.hasDateRowTarget && this.hasCheckboxTarget) {
      const isChecked = this.checkboxTarget.checked
      this.dateRowTarget.style.display = isChecked ? "block" : "none"

      if (!this.dateRowTarget.id) {
        this.dateRowTarget.id = `consumed-date-row-${Math.random().toString(36).substring(2, 9)}`
      }

      this.checkboxTarget.setAttribute("aria-controls", this.dateRowTarget.id)
      this.checkboxTarget.setAttribute("aria-expanded", String(isChecked))
      this.dateRowTarget.setAttribute("aria-hidden", String(!isChecked))

      if (event && isChecked) {
        const input = this.dateRowTarget.querySelector("input:not([type='hidden']), select, textarea")
        if (input) input.focus()
      }
    }
  }
}
