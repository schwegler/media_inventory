import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { initial: String }

  connect() {
    if (this.element.complete && this.element.naturalWidth === 0) this.fallback()
  }

  fallback() {
    const avatar = document.createElement("span")
    avatar.className = "user-avatar-fallback"
    avatar.style.cssText = this.element.style.cssText
    Object.assign(avatar.style, {
      display: "inline-flex", alignItems: "center", justifyContent: "center",
      background: "var(--bg-surface)", color: "var(--text-main)", fontWeight: "600"
    })
    avatar.setAttribute("role", "img")
    avatar.setAttribute("aria-label", this.element.alt)
    avatar.textContent = this.initialValue
    this.element.replaceWith(avatar)
  }
}
