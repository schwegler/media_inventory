import { Controller } from "@hotwired/stimulus"

// Browser choices are scoped to the viewer and invalidated when saved account choices change.
export default class extends Controller {
  static targets = ["mode", "accent", "feedback"]
  connect() {
    this.key = `trove-appearance:v1:${document.body.dataset.viewerId || "guest"}`
    this.preferences = document.body.dataset.uiPreferences || ""
    let saved, account = {}
    try { saved = JSON.parse(localStorage.getItem(this.key)); account = JSON.parse(this.preferences || "{}") } catch { /* Optional storage. */ }
    if (saved?.preferences !== this.preferences) { saved = null; try { localStorage.removeItem(this.key) } catch { /* Optional storage. */ } }
    this.mode = ["os", "light", "dark"].includes(saved?.mode) ? saved.mode : account.theme || "os"
    this.accent = ["violet", "ink", "moss", "halloween"].includes(saved?.accent) ? saved.accent : account.accent || "violet"
    if (!document.documentElement.dataset.season) this.paint()
    this.sync()
  }
  change(event) {
    const { name, value } = event.target
    if (name === "base-mode" && ["os", "light", "dark"].includes(value)) this.mode = value
    else if (name === "base-accent" && ["violet", "ink", "moss"].includes(value)) this.accent = value
    else return
    document.dispatchEvent(new CustomEvent("trove:base-appearance"))
    this.paint()
    try { localStorage.setItem(this.key, JSON.stringify({ mode: this.mode, accent: this.accent, preferences: this.preferences })) } catch { /* Choice works on this page. */ }
    this.feedbackTarget.textContent = "Saved in this browser."
    this.sync()
  }
  paint() { document.documentElement.dataset.theme = this.mode; document.documentElement.dataset.accent = this.accent }
  sync() {
    this.modeTargets.forEach(input => { input.checked = input.value === this.mode })
    this.accentTargets.forEach(input => { input.checked = input.value === this.accent })
  }
}
