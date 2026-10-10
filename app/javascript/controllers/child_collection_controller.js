import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["search", "status", "entry", "result", "empty", "progress", "completed"]

  connect() { this.filter() }
  entryTargetConnected() { if (this.hasSearchTarget) this.filter() }

  filter() {
    const query = this.searchTarget.value.trim().toLocaleLowerCase()
    const status = this.hasStatusTarget ? this.statusTarget.value : "all"
    let visible = 0
    let total = 0
    this.entryTargets.forEach(entry => {
      const panel = entry.closest('[role="tabpanel"]')
      const inSeason = !panel || !panel.hidden
      const matches = entry.dataset.search.toLocaleLowerCase().includes(query) &&
        (status === "all" || entry.dataset.completed === status)
      entry.hidden = !matches
      if (inSeason) { total++; if (matches) visible++ }
    })
    if (this.hasProgressTarget) {
      const completed = this.entryTargets.filter(entry => entry.dataset.completed === "true").length
      this.progressTarget.value = completed
      this.completedTarget.textContent = `${completed} / ${this.entryTargets.length}`
    }
    this.resultTarget.textContent = `${visible} of ${total} shown`
    this.emptyTarget.hidden = visible > 0 || total === 0
  }
}
