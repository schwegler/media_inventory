import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.dataset.connected = "true"
  }
  disconnect() { clearTimeout(this.timer) }
  search() { clearTimeout(this.timer); this.timer = setTimeout(() => this.submit(), 300) }
  submit() { clearTimeout(this.timer); this.element.requestSubmit() }
  start(event) {
    clearTimeout(this.timer)
    // A season button overrides the select's successful-control value.
    const button = event.submitter
    if (button?.name === "season") this.element.querySelector('select[name="season"]').value = button.value
  }
}
