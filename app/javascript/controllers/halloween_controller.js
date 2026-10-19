import { Controller } from "@hotwired/stimulus"
import { currentSeason, SEASONAL_KEYS } from "controllers/season_config"

const ATTRIBUTES = ["theme", "accent", "season", "season-id", "season-motion", "season-effects"]
export default class extends Controller {
  static targets = ["stage", "invitation", "notice", "message", "pause", "atmosphere", "controls"]
  static values = { config: Object }
  connect() {
    window.SchwegSeasonalConfig = this.configValue
    this.season = currentSeason(this.configValue)
    if (!this.season) { if (this.hasControlsTarget) this.controlsTarget.hidden = true; return }
    this.motion = this.read("local", SEASONAL_KEYS.motion) === "paused" ? "paused" : "auto"
    this.stageTarget.dataset.motion = this.motion
    this.syncControls()
    const active = this.readSession()
    if (active && (active.viewer !== this.viewer || active.preferences !== this.preferences)) {
      this.clearSession(); this.write("local", SEASONAL_KEYS.theme, "off")
    } else if (active || this.read("local", SEASONAL_KEYS.theme) === this.season.theme) {
      this.previous = active?.previous || this.snapshot()
      this.closed = active?.closed || false
      this.effects = active?.effects || "on"
      this.paint(); this.showNotice(false); this.saveSession(); this.announce("restore")
    } else if (!this.read("session", SEASONAL_KEYS.prompt(this.season.id)) && this.read("local", SEASONAL_KEYS.theme) !== "off") {
      // Fixed overlay adds no layout height; only visible controls receive pointer events.
      this.stageTarget.hidden = false
      this.invitationTarget.hidden = true
      this.noticeTarget.hidden = true
      const reveal = () => { this.entrance = setTimeout(() => { if (currentSeason(this.configValue)) { this.invitationTarget.hidden = false; this.position() } }, this.configValue.invitationDelayMs || 1000) }
      if (document.readyState === "complete") reveal()
      else { this.ready = reveal; window.addEventListener("load", this.ready, { once: true }) }
    }
    this.reposition = () => { if (!this.frame) this.frame = requestAnimationFrame(() => { this.frame = null; this.position() }) }
    document.addEventListener("focusin", this.reposition)
    window.addEventListener("resize", this.reposition)
    window.addEventListener("scroll", this.reposition, { passive: true })
    if (this.season.window) this.scheduleExpiry()
  }
  position() {
    if (this.stageTarget.hidden || !this.stageTarget.getBoundingClientRect) return
    this.stageTarget.style.visibility = document.querySelector('dialog[open], [aria-modal="true"]') ? "hidden" : "visible"
    const width = this.stageTarget.offsetWidth || 176
    const height = this.stageTarget.offsetHeight || 170
    const margin = 20
    const obstacles = Array.from(document.querySelectorAll('header, nav, [role="alert"], dialog[open], [aria-modal="true"], main button, main a, main input, main select')).filter(node => !this.stageTarget.contains(node)).map(node => node.getBoundingClientRect()).filter(box => box.width && box.height)
    const candidates = [
      [innerWidth - width - margin, Math.max(120, innerHeight * .36)],
      [margin, Math.max(120, innerHeight * .36)],
      [innerWidth - width - margin, innerHeight - height - 100],
      [margin, innerHeight - height - 100]
    ].map(([x, y]) => [Math.max(margin, x), Math.max(margin, Math.min(y, innerHeight - height - 40))])
    const score = ([x, y]) => obstacles.reduce((sum, box) => sum + Math.max(0, Math.min(x + width, box.right + 12) - Math.max(x, box.left - 12)) * Math.max(0, Math.min(y + height, box.bottom + 12) - Math.max(y, box.top - 12)), 0)
    candidates.sort((a, b) => score(a) - score(b))
    this.stageTarget.style.left = `${candidates[0][0]}px`
    this.stageTarget.style.top = `${candidates[0][1]}px`
  }
  scheduleExpiry() {
    this.expiry = setTimeout(() => {
      if (currentSeason(this.configValue)) this.scheduleExpiry()
      else this.expire()
    }, Math.min(Date.parse(this.season.window.until) - Date.now(), 2147483647))
  }
  announce(source) {
    window.dispatchEvent(new CustomEvent("schweg:seasonal-change", { detail: { schemaVersion: 2, seasonId: this.season.id, theme: this.season.theme, active: Boolean(this.previous), motion: this.motion, source } }))
  }
  get viewer() { return document.body.dataset.viewerId || "guest" }
  get preferences() { return document.body.dataset.uiPreferences || "" }
  read(storage, key) { try { return window[`${storage}Storage`].getItem(key) } catch { return null } }
  write(storage, key, value) { try { window[`${storage}Storage`].setItem(key, value) } catch { /* Optional storage. */ } }
  remove(storage, key) { try { window[`${storage}Storage`].removeItem(key) } catch { /* Optional storage. */ } }
  snapshot() { return Object.fromEntries(ATTRIBUTES.map(key => [key, document.documentElement.getAttribute(`data-${key}`)])) }
  readSession() {
    try {
      const state = JSON.parse(this.read("session", SEASONAL_KEYS.active(this.season.id)))
      if (!state?.previous || !ATTRIBUTES.every(key => state.previous[key] === null || typeof state.previous[key] === "string")) return null
      return state
    } catch { return null }
  }
  saveSession() { this.write("session", SEASONAL_KEYS.active(this.season.id), JSON.stringify({ previous: this.previous, closed: this.closed, effects: this.effects, viewer: this.viewer, preferences: this.preferences })) }
  clearSession() { if (this.season) this.remove("session", SEASONAL_KEYS.active(this.season.id)) }
  disconnect() {
    clearTimeout(this.expiry); clearTimeout(this.entrance)
    document.removeEventListener("focusin", this.reposition)
    window.removeEventListener("resize", this.reposition)
    window.removeEventListener("scroll", this.reposition)
    if (this.frame) cancelAnimationFrame(this.frame)
    if (this.ready) window.removeEventListener("load", this.ready)
    this.reset()
  }
  paint() {
    const root = document.documentElement
    root.dataset.theme = "dark"
    root.dataset.accent = this.season.theme
    root.dataset.season = this.season.theme
    root.dataset.seasonId = this.season.id
    root.dataset.seasonMotion = this.motion
    root.dataset.seasonEffects = this.effects || "on"
    this.stageTarget.dataset.motion = this.motion
    this.syncControls()
  }
  syncControls() {
    this.pauseTargets.forEach(button => { button.textContent = this.motion === "paused" ? (button.dataset?.compact ? "Resume" : "Resume motion") : (button.dataset?.compact ? "Pause" : "Pause motion"); button.setAttribute("aria-label", this.motion === "paused" ? "Resume motion" : "Pause motion"); button.setAttribute("aria-pressed", String(this.motion === "paused")) })
    this.atmosphereTargets.forEach(button => { button.textContent = this.effects === "off" ? "Show atmosphere" : "Hide atmosphere"; button.setAttribute("aria-pressed", String(this.effects === "off")); button.disabled = !this.previous })
  }
  showNotice(activated) {
    this.invitationTarget.hidden = true
    this.noticeTarget.hidden = false
    this.stageTarget.hidden = Boolean(this.closed)
    this.messageTarget.textContent = "well. it’s haunted now."
    this.position()
    if (activated) this.noticeTarget.querySelector("button").focus()
  }
  apply() {
    if (!currentSeason(this.configValue)) return this.expire()
    clearTimeout(this.entrance)
    this.previous ||= this.snapshot()
    this.closed = false; this.effects = "on"
    this.write("local", SEASONAL_KEYS.theme, this.season.theme)
    this.paint(); this.showNotice(true); this.saveSession(); this.announce("activation")
  }
  pause() {
    this.motion = this.motion === "paused" ? "auto" : "paused"
    this.write("local", SEASONAL_KEYS.motion, this.motion)
    this.stageTarget.dataset.motion = this.motion
    if (this.previous) { document.documentElement.dataset.seasonMotion = this.motion; this.saveSession() }
    this.syncControls(); this.announce("motion")
  }
  atmosphere() {
    if (!this.previous) return
    this.effects = this.effects === "off" ? "on" : "off"
    document.documentElement.dataset.seasonEffects = this.effects
    this.syncControls(); this.saveSession(); this.announce("atmosphere")
  }
  reset() {
    if (this.previous) {
      for (const [name, value] of Object.entries(this.previous)) {
        if (value === null) document.documentElement.removeAttribute(`data-${name}`)
        else document.documentElement.setAttribute(`data-${name}`, value)
      }
      this.previous = null
    }
    if (this.hasStageTarget) this.stageTarget.hidden = true
    this.syncControls()
  }
  undo() {
    this.reset(); this.clearSession()
    this.write("local", SEASONAL_KEYS.theme, "off")
    this.dismiss(); this.announce("undo")
  }
  dismiss() {
    clearTimeout(this.entrance)
    if (this.previous) { this.closed = true; this.saveSession() }
    this.write("session", SEASONAL_KEYS.prompt(this.season.id), "dismissed")
    this.stageTarget.hidden = true
    document.querySelector("main")?.focus({ preventScroll: true })
  }
  resetChoice() {
    this.reset(); this.clearSession()
    this.remove("local", SEASONAL_KEYS.theme)
    this.remove("session", SEASONAL_KEYS.prompt(this.season.id))
    this.stageTarget.hidden = false; this.invitationTarget.hidden = false; this.noticeTarget.hidden = true; this.announce("reset")
  }
  expire() { this.reset(); this.clearSession(); clearTimeout(this.expiry); clearTimeout(this.entrance); if (this.hasControlsTarget) this.controlsTarget.hidden = true }
}
