import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["accent", "header", "preview"]
  connect() { this.element.dataset.connected = "true" }
  preview() {
    this.previewTarget.dataset.profileAccent = this.accentTarget.value
    this.previewTarget.dataset.profileHeader = this.headerTarget.value
  }
}
