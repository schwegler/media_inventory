import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["copyIcon", "checkIcon", "button"]
  static values = { text: String }

  copy(event) {
    event.preventDefault()

    navigator.clipboard.writeText(this.textValue).then(() => {
      this.showSuccess()
    }).catch(err => {
      console.error('Failed to copy: ', err)
    })
  }

  showSuccess() {
    if (this.hasCopyIconTarget && this.hasCheckIconTarget) {
      this.copyIconTarget.classList.add("hidden")
      this.checkIconTarget.classList.remove("hidden")

      if (this.hasButtonTarget) {
        this.buttonTarget.setAttribute("aria-label", "Copied!")
      }

      setTimeout(() => {
        this.copyIconTarget.classList.remove("hidden")
        this.checkIconTarget.classList.add("hidden")
        if (this.hasButtonTarget) {
          this.buttonTarget.setAttribute("aria-label", "Copy handle")
        }
      }, 2000)
    }
  }
}
