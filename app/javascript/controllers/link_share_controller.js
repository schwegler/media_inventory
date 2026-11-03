import { Controller } from "@hotwired/stimulus"
import { trackPublicShare } from "analytics"

export default class extends Controller {
  static values = { url: String, title: String }
  static targets = ["status", "fallback", "native", "copy"]

  connect() {
    this.element.dataset.connected = "true"
    if (this.hasNativeTarget) this.nativeTarget.hidden = !navigator.share
  }

  disconnect() {
    if (this.timeout) clearTimeout(this.timeout)
    this.restoreCopyButton()
    this.timeout = null
  }

  async share() {
    try {
      await navigator.share({ title: this.titleValue, url: this.urlValue })
      this.showStatus("Shared.")
      trackPublicShare("native")
    } catch (error) {
      if (error.name !== "AbortError") await this.copy()
    }
  }

  async copy(event) {
    const button = event?.currentTarget
    try {
      if (!navigator.clipboard?.writeText) throw new Error("Clipboard unavailable")
      await navigator.clipboard.writeText(this.urlValue)
      if (this.hasFallbackTarget) this.fallbackTarget.hidden = true
      this.showStatus("Link copied.")
      trackPublicShare("copy_link")
      if (button) this.flashButtonSuccess(button)
    } catch {
      if (this.hasFallbackTarget) {
        this.fallbackTarget.hidden = false
        this.fallbackTarget.focus()
        this.fallbackTarget.select()
      }
      this.showStatus("Select and copy this link.", false)
    }
  }

  dismissFallback() {
    if (!this.hasFallbackTarget || this.fallbackTarget.hidden) return
    this.fallbackTarget.hidden = true
    if (this.hasCopyTarget) this.copyTarget.focus()
    this.showStatus("")
  }

  flashButtonSuccess(button) {
    if (this.copyTimeout) clearTimeout(this.copyTimeout)
    if (this.copyButton !== button) {
      this.restoreCopyButton()
      this.copyButton = button
      this.originalAriaLabel = button.getAttribute("aria-label")
    }
    button.setAttribute("aria-label", "Copied!")
    this.copyTimeout = setTimeout(() => this.restoreCopyButton(), 2000)
  }

  restoreCopyButton() {
    if (this.copyTimeout) clearTimeout(this.copyTimeout)
    if (this.copyButton) {
      if (this.originalAriaLabel === null) {
        this.copyButton.removeAttribute("aria-label")
      } else {
        this.copyButton.setAttribute("aria-label", this.originalAriaLabel)
      }
    }
    this.copyButton = null
    this.originalAriaLabel = null
    this.copyTimeout = null
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
