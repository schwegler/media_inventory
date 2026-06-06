import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="consumed-toggle"
// Toggles visibility of consumed_at date field when consumed checkbox is changed
export default class extends Controller {
  static targets = ["checkbox", "dateRow"]

  connect() {
    this.toggle()
  }

  toggle() {
    if (this.hasDateRowTarget && this.hasCheckboxTarget) {
      this.dateRowTarget.style.display = this.checkboxTarget.checked ? "block" : "none"
    }
  }
}
