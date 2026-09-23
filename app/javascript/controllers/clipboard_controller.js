import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["copyIcon", "checkIcon"]
  static values = { text: String }

  connect() {
    this.element.dataset.connected = "true"
  }

  copy(event) {
    event.preventDefault()

    navigator.clipboard.writeText(this.textValue).then(() => {
      this.showSuccess()
    }).catch(err => {
      console.error('Failed to copy: ', err)
    })
  }

  showSuccess() {
    const btn = this.element.querySelector("button") || this.element
    if (!btn.dataset.originalAriaLabel && btn.hasAttribute("aria-label")) {
      btn.dataset.originalAriaLabel = btn.getAttribute("aria-label")
    }

    btn.setAttribute("aria-label", "Copied!")

    if (this.timeout) clearTimeout(this.timeout)

    if (this.hasCopyIconTarget && this.hasCheckIconTarget) {
      this.copyIconTarget.classList.add("hidden")
      this.checkIconTarget.classList.remove("hidden")
    }

    this.timeout = setTimeout(() => {
      if (this.hasCopyIconTarget && this.hasCheckIconTarget) {
        this.copyIconTarget.classList.remove("hidden")
        this.checkIconTarget.classList.add("hidden")
      }
      if (btn.dataset.originalAriaLabel !== undefined) {
        btn.setAttribute("aria-label", btn.dataset.originalAriaLabel)
      } else {
        btn.removeAttribute("aria-label")
      }
    }, 2000)
  }

  disconnect() {
    if (this.timeout) clearTimeout(this.timeout)
  }
}
