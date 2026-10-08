import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String, title: String }
  static targets = ["status", "fallback", "native"]

  connect() {
    if (this.hasNativeTarget) this.nativeTarget.hidden = !navigator.share
  }

  async share() {
    try {
      await navigator.share({ title: this.titleValue, url: this.urlValue })
      this.statusTarget.textContent = "Shared."
    } catch (error) {
      if (error.name !== "AbortError") await this.copy()
    }
  }

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
