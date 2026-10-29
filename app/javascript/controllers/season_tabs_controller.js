import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "tab", "content", "selector", "previous", "next" ]
  static values = { activeSeason: Number, showId: Number }

  connect() {
    this.element.dataset.connected = "true"
    this.restore()
  }

  restore() {
    const seasons = this.contentTargets.map(t => parseInt(t.dataset.season, 10))
    if (seasons.length > 0) {
      let savedSeason = this.hasActiveSeasonValue ? this.activeSeasonValue : null
      try {
        if (this.hasShowIdValue) {
          const storedSeason = sessionStorage.getItem(`tv-show:${this.showIdValue}:season`)
          if (storedSeason !== null) savedSeason = parseInt(storedSeason, 10)
        }
      } catch { /* Storage may be unavailable in embedded browsers. */ }
      const defaultSeason = seasons.includes(1) ? 1 : (seasons.find(season => season > 0) ?? seasons[0])
      const initialSeason = seasons.includes(savedSeason) ? savedSeason : defaultSeason
      this.switchSeason(initialSeason)
    }
  }

  choose() { this.switchSeason(Number(this.selectorTarget.value)) }

  previous() { this.step(-1) }
  next() { this.step(1) }

  step(offset) {
    const seasons = this.contentTargets.map(panel => Number(panel.dataset.season))
    const season = seasons[seasons.indexOf(this.activeSeasonValue) + offset]
    if (season !== undefined) this.switchSeason(season)
  }

  select(event) {
    event.preventDefault()
    const season = parseInt(event.currentTarget.dataset.season, 10)
    this.switchSeason(season)
  }

  keydown(event) {
    const tabs = this.tabTargets
    const currentIndex = tabs.indexOf(event.currentTarget)
    if (currentIndex === -1) return

    let targetIndex = null
    if (event.key === "ArrowRight") {
      targetIndex = (currentIndex + 1) % tabs.length
    } else if (event.key === "ArrowLeft") {
      targetIndex = (currentIndex - 1 + tabs.length) % tabs.length
    } else if (event.key === "Home") {
      targetIndex = 0
    } else if (event.key === "End") {
      targetIndex = tabs.length - 1
    }

    if (targetIndex !== null) {
      event.preventDefault()
      const targetTab = tabs[targetIndex]
      targetTab.focus()
      const season = parseInt(targetTab.dataset.season, 10)
      this.switchSeason(season)
    }
  }

  switchSeason(season) {
    this.activeSeasonValue = season
    try {
      if (this.hasShowIdValue) {
        sessionStorage.setItem(`tv-show:${this.showIdValue}:season`, String(season))
      }
    } catch { /* Tab switching still works without browser storage. */ }

    // Update tab classes and ARIA attributes
    this.tabTargets.forEach((tab) => {
      const isCurrent = parseInt(tab.dataset.season, 10) === season
      tab.classList.toggle("active-tab", isCurrent)
      tab.classList.toggle("inactive-tab", !isCurrent)
      tab.setAttribute("aria-selected", isCurrent ? "true" : "false")
      tab.setAttribute("tabindex", isCurrent ? "0" : "-1")
    })

    // Update content visibility
    this.contentTargets.forEach((content) => {
      const isCurrent = parseInt(content.dataset.season, 10) === season
      content.classList.toggle("hidden", !isCurrent)
      content.hidden = !isCurrent
    })
    if (this.hasSelectorTarget) {
      this.selectorTarget.value = String(season)
      this.selectorTarget.setAttribute('aria-controls', `season-panel-${season}`)
    }
    if (this.hasPreviousTarget) this.previousTarget.disabled = season === Number(this.contentTargets[0]?.dataset.season)
    if (this.hasNextTarget) this.nextTarget.disabled = season === Number(this.contentTargets.at(-1)?.dataset.season)
    this.dispatch("change")
  }
}
