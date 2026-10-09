import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String, title: String }
  static targets = ["status", "fallback", "native"]

  connect() {
    this.element.dataset.connected = "true"
    if (this.hasNativeTarget) this.nativeTarget.hidden = !navigator.share
  }

  disconnect() {
    if (this.timeout) clearTimeout(this.timeout)
  }

  async share() {
    try {
      await navigator.share({ title: this.titleValue, url: this.urlValue })
      this.showStatus("Shared.")
    } catch (error) {
      if (error.name !== "AbortError") await this.copy()
    }
  }

  async copy() {
    try {
      if (!navigator.clipboard?.writeText) throw new Error("Clipboard unavailable")
      await navigator.clipboard.writeText(this.urlValue)
      if (this.hasFallbackTarget) this.fallbackTarget.hidden = true
      this.showStatus("Link copied.")
    } catch {
      if (this.hasFallbackTarget) {
        this.fallbackTarget.hidden = false
        this.fallbackTarget.focus()
        this.fallbackTarget.select()
      }
      this.showStatus("Select and copy this link.", false)
    }
  }

  showStatus(message, autoClear = true) {
    if (this.timeout) clearTimeout(this.timeout)
    if (!this.hasStatusTarget) return

    this.statusTarget.textContent = message
    if (autoClear) {
      this.timeout = setTimeout(() => {
        if (this.hasStatusTarget) this.statusTarget.textContent = ""
      }, 2000)
    }
  }
}
