import { Controller } from "@hotwired/stimulus"

// Turbo replaces custom history state on restoration. Retain presentation by
// history entry, never by URL: a new visit to the same title starts compact.
const presentations = new Map()

// Only this metadata island is tabbed. The page's document navigation stays intact.
export default class extends Controller {
  static targets = ["list", "tab", "panel", "expand"]

  connect() {
    this.element.dataset.connected = "true"
    // Keep native find-in-page available. Unsupported browsers get the full document.
    if (this.tabTargets.length < 2 || !("onbeforematch" in document.documentElement)) return
    this.enhanced = true
    if (this.hasExpandTarget) this.expandTarget.hidden = false
    this.onHash = () => this.applyLocation()
    window.addEventListener("hashchange", this.onHash)
    // Finish a fresh island before resolving an existing downstream fragment.
    // A lazily loaded controller can arrive after the browser's first anchor scroll.
    const saved = this.presentation()
    const target = document.getElementById(location.hash.slice(1))
    const height = this.element.getBoundingClientRect().height
    this.applyLocation()
    if (!saved && target && height !== this.element.getBoundingClientRect().height &&
        (this.element.contains(target) || (this.element.compareDocumentPosition(target) & Node.DOCUMENT_POSITION_FOLLOWING))) {
      target.scrollIntoView({ block: "start", behavior: "instant" })
    }
  }

  applyLocation() {
    const state = this.presentation()
    // Cached DOM may still carry an earlier visit's expanded attributes.
    this.expanded = state?.expanded === true
    this.element.dataset.metadataExpanded = String(this.expanded)
    this.updateExpandButton()
    const index = this.fragmentIndex()
    if (this.expanded) this.reveal()
    else this.select(index >= 0 ? index : (state?.index ?? 0))
  }

  updateExpandButton() {
    if (!this.hasExpandTarget) return
    this.expandTarget.textContent = this.expanded ? "Show tabs" : "Show all"
    this.expandTarget.setAttribute("aria-expanded", String(Boolean(this.expanded)))
    this.expandTarget.setAttribute("aria-controls", this.element.id || "title-details")
  }

  presentation() {
    const entry = history.state?.turbo?.restorationIdentifier
    const saved = history.state?.troveMetadata
    const state = saved?.entry === entry ? saved : presentations.get(entry)
    return state?.path === location.pathname + location.search ? state : undefined
  }

  remember() {
    // Preserve Turbo's restoration identifier rather than replacing history state.
    const entry = history.state?.turbo?.restorationIdentifier
    const state = { path: location.pathname + location.search, entry, expanded: this.expanded, index: this.selectedIndex || 0 }
    if (entry) {
      presentations.delete(entry)
      presentations.set(entry, state)
      if (presentations.size > 20) presentations.delete(presentations.keys().next().value)
    }
    history.replaceState({ ...history.state, troveMetadata: state }, "", location.href)
  }

  disconnect() {
    window.removeEventListener("hashchange", this.onHash)
  }

  fragmentIndex() {
    let id
    try { id = decodeURIComponent(window.location.hash.slice(1)) } catch { return -1 }
    return this.panelTargets.findIndex(panel => panel.id === id || panel.querySelector(`[id="${CSS.escape(id)}"]`))
  }

  choose(event) {
    if (!this.enhanced || this.expanded || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return
    event.preventDefault()
    const index = this.tabTargets.indexOf(event.currentTarget)
    if (location.hash !== event.currentTarget.hash) history.pushState(history.state, "", event.currentTarget.hash)
    this.select(index)
  }

  navigate(event) {
    if (!this.enhanced || this.expanded) return
    const current = this.tabTargets.indexOf(event.currentTarget)
    const last = this.tabTargets.length - 1
    const index = { ArrowRight: (current + 1) % (last + 1), ArrowLeft: (current + last) % (last + 1), Home: 0, End: last }[event.key]
    if (index === undefined) return
    event.preventDefault()
    this.tabTargets[index].focus({ preventScroll: true })
    this.tabTargets[index].scrollIntoView({ block: "nearest", inline: "nearest" })
    history.replaceState(history.state, "", this.tabTargets[index].hash)
    this.select(index)
  }

  select(index) {
    if (!Number.isInteger(index) || index < 0 || index >= this.panelTargets.length) index = 0
    this.selectedIndex = index
    this.element.dataset.metadataSelected = String(index)
    if (this.hasExpandTarget) {
      this.expandTarget.hidden = false
      this.updateExpandButton()
    }
    this.listTarget.setAttribute("role", "tablist")
    this.tabTargets.forEach((tab, i) => {
      tab.setAttribute("role", "tab")
      tab.setAttribute("aria-controls", this.panelTargets[i].id)
      tab.setAttribute("aria-selected", String(i === index))
      tab.tabIndex = i === index ? 0 : -1
    })
    this.panelTargets.forEach((panel, i) => {
      panel.setAttribute("role", "tabpanel")
      panel.setAttribute("aria-labelledby", this.tabTargets[i].id)
      panel.tabIndex = i === index ? 0 : -1
      if (i === index) panel.removeAttribute("hidden")
      else panel.setAttribute("hidden", "until-found")
    })
    this.element.dataset.tabbed = "true"
    this.remember()
  }

  found(event) {
    if (!this.enhanced || this.expanded) return
    const index = this.panelTargets.indexOf(event.currentTarget)
    if (index < 0) return
    // Keep a found panel selected if a pending Turbo restore reconnects the island.
    history.replaceState(history.state, "", this.tabTargets[index].hash)
    this.select(index)
  }

  expand() {
    this.expanded = !this.expanded
    this.element.dataset.metadataExpanded = String(this.expanded)
    this.updateExpandButton()
    if (this.expanded) this.reveal()
    else this.select(Math.max(0, this.fragmentIndex()))
    this.remember()
  }

  reveal() {
    delete this.element.dataset.tabbed
    if (this.hasExpandTarget) this.updateExpandButton()
    this.listTarget.removeAttribute("role")
    this.tabTargets.forEach(tab => {
      for (const name of ["role", "aria-controls", "aria-selected", "tabindex"]) tab.removeAttribute(name)
    })
    this.panelTargets.forEach(panel => {
      for (const name of ["hidden", "role", "tabindex"]) panel.removeAttribute(name)
      panel.setAttribute("aria-labelledby", `${panel.id}-heading`)
    })
  }
}
