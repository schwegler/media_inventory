import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["copyIcon", "checkIcon", "button"]
  static values = { text: String }

  connect() {
    this.element.dataset.connected = "true"
  }

  disconnect() {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
  }

  copy(event) {
    event.preventDefault()

    navigator.clipboard.writeText(this.textValue).then(() => {
      this.showSuccess(event.currentTarget)
    }).catch(err => {
      console.error('Failed to copy: ', err)
    })
  }

  showSuccess(button) {
    if (!this.hasCopyIconTarget || !this.hasCheckIconTarget) return

    const targetBtn = button || (this.hasButtonTarget ? this.buttonTarget : this.element.querySelector("button"))

    if (this.timeout) {
      clearTimeout(this.timeout)
      this.timeout = null
    } else if (targetBtn) {
      this.hasOriginalAriaLabel = targetBtn.hasAttribute("aria-label")
      this.originalAriaLabel = targetBtn.getAttribute("aria-label")
    }

    this.copyIconTarget.classList.add("hidden")
    this.checkIconTarget.classList.remove("hidden")

    if (targetBtn) {
      targetBtn.setAttribute("aria-label", "Copied!")
    }

    this.timeout = setTimeout(() => {
      this.copyIconTarget.classList.remove("hidden")
      this.checkIconTarget.classList.add("hidden")

      if (targetBtn) {
        if (this.hasOriginalAriaLabel) {
          targetBtn.setAttribute("aria-label", this.originalAriaLabel)
        } else {
          targetBtn.removeAttribute("aria-label")
        }
      }

      this.timeout = null
      this.originalAriaLabel = null
      this.hasOriginalAriaLabel = false
    }, 2000)
  }
}
