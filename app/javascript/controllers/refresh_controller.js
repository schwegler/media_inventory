import { Turbo } from "@hotwired/turbo-rails"
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.panel = this.element.closest("#metadata-health")
    if (!this.panel) return
    this.connected = true
    this.key = `trove:metadata:${this.panel.dataset.refreshUrl}`
    this.pending = this.readPending()
    if (this.panel.dataset.refreshResult === "true") {
      this.status?.focus({ preventScroll: true })
      this.panel.scrollIntoView({ block: "center" })
      if (this.panel.dataset.refreshState === "refreshing" && !this.pending) this.begin()
    }
    if (this.panel.dataset.refreshState !== "refreshing") return this.clearPending()
    if (this.pending) this.schedule()
  }

  get status() { return this.panel?.querySelector('[role="status"]') }

  disconnect() {
    this.connected = false
    clearTimeout(this.pollTimer)
    this.abort?.abort()
  }

  readPending() {
    try {
      const value = JSON.parse(sessionStorage.getItem(this.key))
      return value && Date.now() - value.startedAt < 120000 ? value : null
    } catch { return null }
  }

  begin() {
    this.pending = { startedAt: Date.now(), count: 0 }
    this.savePending()
  }

  savePending() {
    try { sessionStorage.setItem(this.key, JSON.stringify(this.pending)) } catch { /* storage is optional */ }
  }

  clearPending() {
    this.pending = null
    try { sessionStorage.removeItem(this.key) } catch { /* storage is optional */ }
  }

  schedule() {
    clearTimeout(this.pollTimer)
    if (!this.connected || !this.pending) return
    if (this.pending.count >= 10 || Date.now() - this.pending.startedAt >= 120000) {
      if (this.status) this.status.textContent = "Metadata check is taking longer than expected. Please check back later."
      this.clearPending()
      return
    }
    this.pollTimer = setTimeout(() => this.poll(), Math.min(2000 + this.pending.count * 500, 5000))
  }

  async poll() {
    if (!this.connected || !this.pending) return
    this.pending.count++
    this.savePending()
    this.abort = new AbortController()
    try {
      const response = await fetch(this.panel.dataset.refreshUrl, {
        headers: { Accept: "application/json" }, credentials: "same-origin", cache: "no-store", signal: this.abort.signal
      })
      if (!this.connected) return
      if (!response.ok || response.redirected) {
        if (this.status) this.status.textContent = "Unable to check metadata status. Reload this page to try again."
        this.clearPending()
        return
      }
      const result = await response.json()
      if (!this.connected) return
      if (this.status && result.message) this.status.textContent = result.message
      this.pending.requestId = result.request_id
      this.savePending()
      if (result.state !== "refreshing") {
        this.clearPending()
        if (["success", "partial", "unchanged"].includes(result.state)) Turbo.visit(window.location.href, { action: "replace" })
        return
      }
    } catch (error) {
      if (!this.connected || error.name === "AbortError") return
    }
    this.schedule()
  }

  start() {
    this.begin()
    this.element.setAttribute("aria-busy", "true")
    if (this.status) this.status.textContent = "Checking artwork and metadata…"
  }

  finish(event) {
    this.element.removeAttribute("aria-busy")
    if (event.detail.success) this.schedule()
    else {
      this.clearPending()
      const response = event.detail.fetchResponse
      const message = response?.statusCode === 403
        ? "You do not have permission to refresh this title."
        : response ? "Unable to refresh metadata. Please try again." : "Unable to connect. Please try again."
      if (this.status) this.status.textContent = message
    }
  }
}
