import { Controller } from "@hotwired/stimulus"

const END = Date.UTC(2026, 10, 1)
const START = Date.UTC(2026, 9, 18)
const KEY = "trove-halloween-2026"
const ACTIVE = `${KEY}-active`
export default class extends Controller {
  static targets = ["invitation", "notice", "message"]
  connect() {
    if (Date.now() < START || Date.now() >= END) { this.clearSession(); return }
    const active = this.readSession()
    if (active && active.viewer === this.viewer && active.preferences === this.preferences) {
      this.previous = active.previous
      this.closed = active.closed
      this.paint()
      this.showNotice(false)
    } else {
      this.clearSession()
      this.invitationTarget.hidden = false
      this.noticeTarget.hidden = true
      try { if (localStorage.getItem(KEY)) return } catch { /* Optional storage. */ }
      this.element.hidden = false
    }
    // One deadline timer, never polling. Recheck the date on every action as well.
    this.expiry = setTimeout(() => this.expire(), Math.min(END - Date.now(), 2147483647))
  }
  get viewer() { return document.body.dataset.viewerId || "guest" }
  get preferences() { return document.body.dataset.uiPreferences || "" }
  readSession() {
    try {
      const state = JSON.parse(sessionStorage.getItem(ACTIVE))
      if (!state?.previous || ![null, "os", "light", "dark"].includes(state.previous.theme) ||
          ![null, "violet", "ink", "moss", "halloween"].includes(state.previous.accent)) return null
      return state
    } catch { return null }
  }
  saveSession() {
    try { sessionStorage.setItem(ACTIVE, JSON.stringify({ previous: this.previous, closed: this.closed, viewer: this.viewer, preferences: this.preferences })) } catch { /* Page-only without storage. */ }
  }
  clearSession() { try { sessionStorage.removeItem(ACTIVE) } catch { /* Optional storage. */ } }
  disconnect() { clearTimeout(this.expiry); this.reset() }
  paint() {
    document.documentElement.dataset.theme = "dark"
    document.documentElement.dataset.accent = "halloween"
  }
  showNotice(activated) {
    this.invitationTarget.hidden = true
    this.noticeTarget.hidden = false
    this.element.hidden = Boolean(this.closed)
    this.messageTarget.textContent = activated
      ? "Halloween appearance applied for this browser session. Your saved preferences are unchanged."
      : "Halloween appearance is on for this browser session. Your saved preferences are unchanged."
    if (activated) this.noticeTarget.querySelector("button").focus()
  }
  apply() {
    if (Date.now() < START || Date.now() >= END) return this.expire()
    const root = document.documentElement
    this.previous = { theme: root.getAttribute("data-theme"), accent: root.getAttribute("data-accent") }
    this.closed = false
    this.saveSession()
    this.paint()
    this.showNotice(true)
  }
  reset() {
    if (this.previous) {
      for (const [name, value] of Object.entries(this.previous)) {
        if (value === null) document.documentElement.removeAttribute(`data-${name}`)
        else document.documentElement.setAttribute(`data-${name}`, value)
      }
      this.previous = null
    }
    this.element.hidden = true
  }
  undo() { this.reset(); this.clearSession(); this.dismiss() }
  dismiss() {
    if (this.previous) { this.closed = true; this.saveSession() }
    try { localStorage.setItem(KEY, "dismissed") } catch { /* Still dismiss this page. */ }
    this.element.hidden = true
    document.querySelector("main")?.focus({ preventScroll: true })
  }
  expire() { this.reset(); this.clearSession(); clearTimeout(this.expiry) }
}
