import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }
  static targets = ["status", "fallback"]

  async copy() {
    try {
      if (!navigator.clipboard?.writeText) throw new Error("Clipboard unavailable")
      await navigator.clipboard.writeText(this.urlValue)
      this.fallbackTarget.hidden = true
      this.statusTarget.textContent = "Link copied."
    } catch {
      this.fallbackTarget.hidden = false
      this.fallbackTarget.focus()
      this.fallbackTarget.select()
      this.statusTarget.textContent = "Select and copy this link."
    }
  }
}
