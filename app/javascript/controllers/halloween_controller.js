import { Controller } from "@hotwired/stimulus"

const END = Date.UTC(2026, 10, 1)
const START = Date.UTC(2026, 9, 18)
const KEY = "trove-halloween-2026"
export default class extends Controller {
  static targets = ["invitation", "notice", "message"]
  connect() {
    if (Date.now() < START || Date.now() >= END) return
    try { if (localStorage.getItem(KEY)) return } catch { /* Optional storage. */ }
    this.element.hidden = false
    // One deadline timer, never polling. Recheck the date on every action as well.
    this.expiry = setTimeout(() => this.expire(), Math.min(END - Date.now(), 2147483647))
  }
  disconnect() { clearTimeout(this.expiry); this.reset() }
  apply() {
    if (Date.now() >= END) return this.expire()
    const root = document.documentElement
    this.previous = { theme: root.getAttribute("data-theme"), accent: root.getAttribute("data-accent") }
    root.dataset.theme = "dark"
    root.dataset.accent = "halloween"
    this.invitationTarget.hidden = true
    this.noticeTarget.hidden = false
    this.messageTarget.textContent = "Halloween appearance applied for this page. Your saved preferences are unchanged."
    this.noticeTarget.querySelector("button").focus()
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
  undo() { this.reset(); this.dismiss() }
  dismiss() {
    try { localStorage.setItem(KEY, "dismissed") } catch { /* Still dismiss this page. */ }
    this.element.hidden = true
    document.querySelector("main")?.focus({ preventScroll: true })
  }
  expire() { this.reset(); clearTimeout(this.expiry) }
}
