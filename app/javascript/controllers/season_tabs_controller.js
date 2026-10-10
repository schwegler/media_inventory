import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "tab", "content" ]
  static values = { activeSeason: Number, showId: Number }

  connect() {
    this.element.dataset.connected = "true"
    this.restore()
  }

  restore() {
    const seasons = this.tabTargets.map(t => parseInt(t.dataset.season, 10))
    if (seasons.length > 0) {
      let savedSeason = this.activeSeasonValue
      try {
        if (this.hasShowIdValue) {
          const storedSeason = sessionStorage.getItem(`tv-show:${this.showIdValue}:season`)
          if (storedSeason !== null) savedSeason = parseInt(storedSeason, 10)
        }
      } catch { /* Storage may be unavailable in embedded browsers. */ }
      const initialSeason = seasons.includes(savedSeason) ? savedSeason : seasons[0]
      this.switchSeason(initialSeason)
    }
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
    this.dispatch("change")
  }
}
