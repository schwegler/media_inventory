import { Controller } from "@hotwired/stimulus"
import { availableSeason, currentSeason, SEASONAL_KEYS } from "controllers/season_config"

const ATTRIBUTES = ["theme", "accent", "season", "season-id", "season-motion", "season-effects"]
export default class extends Controller {
  static targets = ["stage", "invitation", "notice", "message", "pause", "atmosphere", "controls", "undo", "on", "off", "announcement"]
  static values = { config: Object }
  connect() {
    window.SchwegSeasonalConfig = this.configValue
    this.season = availableSeason(this.configValue)
    if (!this.season) { if (this.hasControlsTarget) this.controlsTarget.hidden = true; return }
    this.motion = this.read("local", SEASONAL_KEYS.motion) === "paused" ? "paused" : "auto"
    this.stageTarget.dataset.motion = this.motion
    this.syncControls()
    let active = this.readSession()
    if (active && (active.viewer !== this.viewer || active.preferences !== this.preferences)) {
      this.clearSession(); this.write("local", SEASONAL_KEYS.theme, "off"); active = null
    }
    const accountTheme = this.accountPreferences.seasonalTheme
    this.accountTheme = accountTheme
    const wantsTheme = active || accountTheme === this.season.theme ||
      (!this.preferencesUrl && this.read("local", SEASONAL_KEYS.theme) === this.season.theme)
    if (wantsTheme) {
      this.previous = active?.previous || this.snapshot()
      this.closed = active?.closed ?? (Boolean(this.read("session", SEASONAL_KEYS.prompt(this.season.id))) || !currentSeason(this.configValue) || accountTheme === this.season.theme)
      this.effects = active?.effects || "on"
      this.paint(); this.showNotice(false); this.saveSession(); this.announce("restore")
    } else if (currentSeason(this.configValue) && !this.read("session", SEASONAL_KEYS.prompt(this.season.id)) && this.read("local", SEASONAL_KEYS.theme) !== "off") {
      this.stageTarget.hidden = false
      this.invitationTarget.hidden = true
      this.noticeTarget.hidden = true
      const reveal = () => { this.entrance = setTimeout(() => { if (currentSeason(this.configValue)) { this.invitationTarget.hidden = false; this.position() } }, this.configValue.invitationDelayMs || 1000) }
      if (document.readyState === "complete") reveal()
      else { this.ready = reveal; window.addEventListener("load", this.ready, { once: true }) }
    }
    this.reposition = () => { if (!this.frame) this.frame = requestAnimationFrame(() => { this.frame = null; this.position() }) }
    document.addEventListener("focusin", this.reposition)
    document.addEventListener("click", this.reposition)
    if (window.ResizeObserver) { this.observer = new window.ResizeObserver(this.reposition); this.observer.observe(document.body) }
    window.addEventListener("resize", this.reposition)
    window.addEventListener("scroll", this.reposition, { passive: true })
    if (currentSeason(this.configValue)?.window) this.scheduleExpiry()
  }
  refresh() {
    const preferences = this.accountPreferences
    if (!this.season || preferences.seasonalTheme === this.accountTheme) return
    this.accountTheme = preferences.seasonalTheme
    const previous = this.snapshot()
    previous.theme = preferences.theme || "os"; previous.accent = preferences.accent || "violet"
    for (const key of ["season", "season-id", "season-motion", "season-effects"]) previous[key] = null
    this.previous = previous; this.clearSession()
    if (this.accountTheme === this.season.theme) {
      this.closed = true; this.effects = "on"; this.paint(); this.showNotice(false); this.saveSession()
    } else { this.reset(); this.write("local", SEASONAL_KEYS.theme, "off") }
    this.announce("settings")
  }
  position() {
    if (this.stageTarget.hidden || !this.stageTarget.getBoundingClientRect) return
    this.stageTarget.style.visibility = document.querySelector('dialog[open], [aria-modal="true"]') ? "hidden" : "visible"
    const width = this.stageTarget.offsetWidth || 176
    const height = this.stageTarget.offsetHeight || 170
    const margin = 20
    const obstacles = Array.from(document.querySelectorAll('header, nav, [role="alert"], dialog[open], [aria-modal="true"], .appearance-menu[open] .appearance-panel, main button, main a, main input, main select')).filter(node => !this.stageTarget.contains(node)).map(node => node.getBoundingClientRect()).filter(box => box.width && box.height)
    const candidates = [
      [innerWidth - width - margin, Math.max(120, innerHeight * .36)],
      [margin, Math.max(120, innerHeight * .36)],
      [innerWidth - width - margin, innerHeight - height - 100],
      [margin, innerHeight - height - 100]
    ].map(([x, y]) => [Math.max(margin, x), Math.max(margin, Math.min(y, innerHeight - height - 40))])
    const current = [parseFloat(this.stageTarget.style.left), parseFloat(this.stageTarget.style.top)]
    if (current.every(Number.isFinite) && current[0] >= margin && current[0] + width <= innerWidth - margin && current[1] >= margin && current[1] + height <= innerHeight - 40) candidates.unshift(current)
    const score = ([x, y]) => obstacles.reduce((sum, box) => sum + Math.max(0, Math.min(x + width, box.right + 12) - Math.max(x, box.left - 12)) * Math.max(0, Math.min(y + height, box.bottom + 12) - Math.max(y, box.top - 12)), 0)
    candidates.sort((a, b) => score(a) - score(b))
    // Dense forms can occupy every edge. Defer the decoration until a clear position exists.
    if (score(candidates[0]) > 0) this.stageTarget.style.visibility = "hidden"
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
  get accountPreferences() { try { return JSON.parse(this.preferences || "{}") } catch { return {} } }
  get preferencesUrl() { return document.body.dataset.seasonalPreferencesUrl }
  persistTheme(theme) {
    if (!this.preferencesUrl) return
    const url = this.preferencesUrl, viewer = this.viewer
    this.preferenceWrite = (this.preferenceWrite || Promise.resolve()).then(async () => {
      if ((document.body.dataset.viewerId || "guest") !== viewer) return
      const response = await fetch(url, { method: "PATCH", keepalive: true, headers: { "Content-Type": "application/json", Accept: "application/json", "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || "" }, body: JSON.stringify({ user: { seasonal_theme: theme } }) })
      if (!response.ok) throw new Error("Appearance was not saved")
      const result = await response.json()
      if ((document.body.dataset.viewerId || "guest") !== viewer) return
      document.body.dataset.uiPreferences = JSON.stringify(result.preferences)
      this.accountTheme = result.preferences.seasonalTheme
      const active = this.readSession()
      if (active?.viewer === viewer) this.write("session", SEASONAL_KEYS.active(this.season.id), JSON.stringify({ ...active, preferences: this.preferences }))
    }).catch(() => { if (this.hasAnnouncementTarget) this.announcementTarget.textContent = "Your browser theme is active, but the account preference could not be saved. Try again in Appearance settings." })
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
    document.removeEventListener("click", this.reposition)
    this.observer?.disconnect()
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
  baseChoice() {
    this.reset(); this.clearSession(); this.write("local", SEASONAL_KEYS.theme, "off"); this.persistTheme("off"); this.announce("base-choice")
  }
  character() {
    if (this.previous) this.openAppearance()
    else this.apply()
  }
  openAppearance() {
    const menu = document.querySelector("details.appearance-menu")
    if (menu) menu.open = true
    this.noticeTarget.querySelector("button")?.focus()
  }
  syncControls() {
    const active = Boolean(this.previous)
    ;(this.undoTargets || []).forEach(button => { button.disabled = !active })
    ;(this.onTargets || []).forEach(button => button.setAttribute("aria-pressed", String(active)))
    ;(this.offTargets || []).forEach(button => button.setAttribute("aria-pressed", String(!active)))
    this.invitationTarget?.querySelector?.(".halloween-bat")?.setAttribute("aria-label", active ? "Open Halloween appearance controls" : "Turn on Halloween mode")
    this.pauseTargets.forEach(button => { button.textContent = this.motion === "paused" ? (button.dataset?.compact ? "Resume" : "Resume motion") : (button.dataset?.compact ? "Pause" : "Pause motion"); button.setAttribute("aria-label", this.motion === "paused" ? "Resume motion" : "Pause motion"); button.setAttribute("aria-pressed", String(this.motion === "paused")) })
    this.atmosphereTargets.forEach(button => { button.textContent = this.effects === "off" ? "Show atmosphere" : "Hide atmosphere"; button.setAttribute("aria-pressed", String(this.effects === "off")); button.disabled = !this.previous })
  }
  showNotice(activated) {
    this.invitationTarget.hidden = false
    this.noticeTarget.hidden = false
    this.stageTarget.hidden = Boolean(this.closed)
    this.messageTarget.textContent = "well. it’s haunted now."
    this.position()
    if (activated) {
      if (this.hasAnnouncementTarget) this.announcementTarget.textContent = "well. it’s haunted now. Undo is available in Appearance."
      document.querySelector("details.appearance-menu > summary")?.focus({ preventScroll: true })
    }
  }
  apply() {
    if (!this.season) return
    clearTimeout(this.entrance)
    this.previous ||= this.snapshot()
    this.closed = Boolean(this.read("session", SEASONAL_KEYS.prompt(this.season.id))) || (!currentSeason(this.configValue) && this.stageTarget.hidden); this.effects = "on"
    this.write("local", SEASONAL_KEYS.theme, this.season.theme)
    this.paint(); this.showNotice(true); this.saveSession(); this.persistTheme(this.season.theme); this.announce("activation")
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
    if (this.noticeTarget) this.noticeTarget.hidden = true
    if (this.hasAnnouncementTarget) this.announcementTarget.textContent = ""
    this.syncControls()
  }
  undo() {
    this.reset(); this.clearSession()
    this.write("local", SEASONAL_KEYS.theme, "off"); this.persistTheme("off")
    this.dismiss(); this.announce("undo")
  }
  dismiss() {
    clearTimeout(this.entrance)
    if (this.previous) { this.closed = true; this.saveSession() }
    this.write("session", SEASONAL_KEYS.prompt(this.season.id), "dismissed")
    this.stageTarget.hidden = true
    const menu = document.querySelector("details.appearance-menu")
    if (menu) menu.open = false
    document.querySelector("main")?.focus({ preventScroll: true })
  }
  resetChoice() {
    clearTimeout(this.entrance)
    this.closed = false
    this.remove("session", SEASONAL_KEYS.prompt(this.season.id))
    if (this.previous) this.saveSession()
    else { this.clearSession(); this.remove("local", SEASONAL_KEYS.theme) }
    this.stageTarget.hidden = false; this.invitationTarget.hidden = false; this.position(); this.announce("reset")
  }
  expire() { clearTimeout(this.expiry); clearTimeout(this.entrance); this.stageTarget.hidden = true; if (this.previous) { this.closed = true; this.saveSession() } }
}
