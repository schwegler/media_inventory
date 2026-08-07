import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["copyIcon", "checkIcon"]
  static values = { text: String }

  copy(event) {
    event.preventDefault()
    const button = event.currentTarget

    navigator.clipboard.writeText(this.textValue).then(() => {
      this.showSuccess(button)
    }).catch(err => {
      console.error('Failed to copy: ', err)
    })
  }

  showSuccess(button) {
    if (this.hasCopyIconTarget && this.hasCheckIconTarget) {
      this.copyIconTarget.classList.add("hidden")
      this.checkIconTarget.classList.remove("hidden")

      const originalLabel = button ? button.getAttribute("aria-label") : "Copy handle"
      if (button) {
        button.setAttribute("aria-label", "Copied!")
      }

      setTimeout(() => {
        this.copyIconTarget.classList.remove("hidden")
        this.checkIconTarget.classList.add("hidden")
        if (button) {
          button.setAttribute("aria-label", originalLabel)
        }
      }, 2000)
    }
  }
}
