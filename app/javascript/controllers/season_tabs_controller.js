import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "tab", "content" ]
  static values = { activeSeason: Number }

  connect() {
    const seasons = this.tabTargets.map(t => parseInt(t.dataset.season, 10))
    if (seasons.length > 0) {
      const initialSeason = seasons.includes(this.activeSeasonValue) ? this.activeSeasonValue : seasons[0]
      this.switchSeason(initialSeason)
    }
  }

  select(event) {
    event.preventDefault()
    const season = parseInt(event.currentTarget.dataset.season, 10)
    this.switchSeason(season)
  }

  switchSeason(season) {
    this.activeSeasonValue = season

    // Update tab classes
    this.tabTargets.forEach((tab) => {
      const isCurrent = parseInt(tab.dataset.season, 10) === season
      tab.classList.toggle("active-tab", isCurrent)
      tab.classList.toggle("inactive-tab", !isCurrent)
    })

    // Update content visibility
    this.contentTargets.forEach((content) => {
      const isCurrent = parseInt(content.dataset.season, 10) === season
      content.classList.toggle("hidden", !isCurrent)
    })
  }
}
