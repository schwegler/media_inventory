import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["copyIcon", "checkIcon"]
  static values = { text: String }

  connect() {
    this.element.dataset.connected = "true"
  }

  disconnect() {
    if (this.copyTimeout) {
      clearTimeout(this.copyTimeout)
      this.copyTimeout = null
    }
  }

  async copy(event) {
    if (event) event.preventDefault()
    const button = event?.currentTarget

    try {
      if (!navigator.clipboard?.writeText) throw new Error("Clipboard unavailable")
      await navigator.clipboard.writeText(this.textValue)
      this.showSuccess(button)
    } catch (err) {
      console.error("Failed to copy: ", err)
    }
  }

  showSuccess(button) {
    if (this.copyTimeout) {
      clearTimeout(this.copyTimeout)
      this.copyTimeout = null
    }

    if (button) {
      if (button.dataset.originalAriaLabel === undefined) {
        button.dataset.originalAriaLabel = button.getAttribute("aria-label") || ""
      }
      button.setAttribute("aria-label", "Copied!")
    }

    if (this.hasCopyIconTarget && this.hasCheckIconTarget) {
      this.copyIconTarget.classList.add("hidden")
      this.checkIconTarget.classList.remove("hidden")
    }

    this.copyTimeout = setTimeout(() => {
      if (this.hasCopyIconTarget && this.hasCheckIconTarget) {
        this.copyIconTarget.classList.remove("hidden")
        this.checkIconTarget.classList.add("hidden")
      }

      if (button) {
        if (button.dataset.originalAriaLabel) {
          button.setAttribute("aria-label", button.dataset.originalAriaLabel)
        } else {
          button.removeAttribute("aria-label")
        }
        delete button.dataset.originalAriaLabel
      }

      this.copyTimeout = null
    }, 2000)
  }
}
