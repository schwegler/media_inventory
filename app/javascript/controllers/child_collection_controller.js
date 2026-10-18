import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["search", "status", "entry", "result", "empty", "progress", "completed"]

  connect() { this.filter() }
  // Stimulus connects every entry individually. Batch those callbacks so a
  // large collection is scanned once, including after Turbo replaces entries.
  entryTargetConnected() { this.scheduleFilter() }
  entryTargetDisconnected() { this.scheduleFilter() }

  scheduleFilter() {
    if (this.filterScheduled) return
    this.filterScheduled = true
    queueMicrotask(() => {
      this.filterScheduled = false
      if (this.element.isConnected && this.hasSearchTarget) this.filter()
    })
  }

  filter() {
    const query = this.searchTarget.value.trim().toLocaleLowerCase()
    const status = this.hasStatusTarget ? this.statusTarget.value : "all"
    let visible = 0
    let total = 0
    this.entryTargets.forEach(entry => {
      const panel = entry.closest('[data-season-tabs-target="content"]')
      const inSeason = !panel || !panel.hidden
      const matches = entry.dataset.search.toLocaleLowerCase().includes(query) &&
        (status === "all" || entry.dataset.completed === status)
      entry.hidden = !matches
      if (inSeason) { total++; if (matches) visible++ }
    })
    if (this.hasProgressTarget) {
      const completed = this.entryTargets.filter(entry => entry.dataset.completed === "true").length
      this.progressTarget.value = completed
      this.completedTarget.textContent = `${completed.toLocaleString()} of ${this.entryTargets.length.toLocaleString()}`
    }
    this.element.querySelectorAll('.season-episodes-list[data-season-tabs-target="content"]').forEach(panel => {
      const entries = [...panel.querySelectorAll('[data-child-collection-target="entry"]')]
      const count = entries.filter(entry => entry.dataset.completed === "true").length
      const tally = panel.querySelector('.season-watched-tally')
      if (tally) tally.textContent = `${count} of ${entries.length} watched`
      const form = panel.querySelector('.season-panel-actions form')
      if (form) {
        const all = count === entries.length
        form.querySelector('[name="consumed"]').value = String(!all)
        const button = form.querySelector('button')
        button.textContent = all ? "Undo season" : "Mark season watched"
        button.setAttribute('aria-label', `${all ? 'Mark as unwatched' : 'Mark as watched'}: Season ${panel.dataset.season}`)
        button.dataset.turboConfirm = all ? "Mark this season unwatched in this pass?" : "Mark this season watched in this pass?"
      }
    })
    const issueTally = this.element.querySelector('.issue-read-tally')
    if (issueTally) {
      const count = this.entryTargets.filter(entry => entry.dataset.completed === "true").length
      issueTally.textContent = `${count} of ${this.entryTargets.length} read`
      const form = this.element.querySelector('.issue-bulk-actions form')
      if (form) {
        const all = count === this.entryTargets.length
        form.querySelector('[name="consumed"]').value = String(!all)
        const button = form.querySelector('button')
        button.textContent = all ? "Undo all read" : "Mark all read"
        button.setAttribute('aria-label', all ? "Mark all issues as unread" : "Mark all issues as read")
        button.dataset.turboConfirm = all ? "Mark all issues unread in this pass?" : "Mark all issues read in this pass?"
      }
    }
    this.resultTarget.textContent = `${visible} of ${total} shown`
    this.emptyTarget.hidden = visible > 0 || total === 0
  }
}
