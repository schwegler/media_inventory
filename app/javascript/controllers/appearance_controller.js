import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["accent", "header", "preview"]
  connect() { this.element.dataset.connected = "true" }
  preview() {
    this.previewTarget.dataset.profileAccent = this.accentTargets.find(input => input.checked)?.value || this.accentTarget.value
    this.previewTarget.dataset.profileHeader = this.headerTargets.find(input => input.checked)?.value || this.headerTarget.value
  }
}
