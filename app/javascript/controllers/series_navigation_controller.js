import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.dataset.connected = "true"
    const filters = this.element.querySelector(".series-filters")
    if (filters && filters.dataset.activeFilters !== "true" && window.matchMedia("(max-width: 580px)").matches) filters.open = false
  }
  disconnect() { clearTimeout(this.timer) }
  search() { clearTimeout(this.timer); this.timer = setTimeout(() => this.submit(), 300) }
  submit() { this.element.requestSubmit() }
  start(event) {
    // A season button overrides the select's successful-control value.
    const button = event.submitter
    if (button?.name === "season") this.element.querySelector('select[name="season"]').value = button.value
  }
}
