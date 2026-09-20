import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.dataset.connected = "true"
  }

  submit() {
    this.element.requestSubmit()
  }
}
