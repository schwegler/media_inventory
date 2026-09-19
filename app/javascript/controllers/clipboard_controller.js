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
    const triggerBtn = event.currentTarget

    navigator.clipboard.writeText(this.textValue).then(() => {
      this.showSuccess(triggerBtn)
    }).catch(err => {
      console.error('Failed to copy: ', err)
    })
  }

  showSuccess(triggerBtn) {
    const btn = triggerBtn || (this.hasButtonTarget ? this.buttonTarget : null)

    if (this.hasCopyIconTarget && this.hasCheckIconTarget) {
      this.copyIconTarget.classList.add("hidden")
      this.checkIconTarget.classList.remove("hidden")

      if (btn) {
        if (!("originalAriaLabel" in btn.dataset)) {
          btn.dataset.originalAriaLabel = btn.getAttribute("aria-label") || ""
        }
        btn.setAttribute("aria-label", "Copied!")
      }

      if (this.timeout) {
        clearTimeout(this.timeout)
      }

      this.timeout = setTimeout(() => {
        this.copyIconTarget.classList.remove("hidden")
        this.checkIconTarget.classList.add("hidden")
        if (btn) {
          const original = btn.dataset.originalAriaLabel
          if (original) {
            btn.setAttribute("aria-label", original)
          } else {
            btn.removeAttribute("aria-label")
          }
          delete btn.dataset.originalAriaLabel
        }
      }, 2000)
    }
  }
}
