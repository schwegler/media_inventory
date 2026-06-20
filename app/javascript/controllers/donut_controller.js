import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { percentage: Number }

  connect() {
    this.element.style.background = `conic-gradient(#3b82f6 0% ${this.percentageValue}%, #1e293b ${this.percentageValue}% 100%)`
  }
}
