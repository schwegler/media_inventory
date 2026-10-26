import { Controller } from "@hotwired/stimulus"

// Only this metadata island is tabbed. The page's document navigation stays intact.
export default class extends Controller {
  static targets = ["list", "tab", "panel", "expand"]

  connect() {
    // Keep native find-in-page available. Unsupported browsers get the full document.
    if (this.tabTargets.length < 2 || !("onbeforematch" in document.documentElement)) return
    this.enhanced = true
    this.expanded = false
    this.expandTarget.hidden = false
    this.onHash = () => {
      const index = this.fragmentIndex()
      if (!this.expanded) this.select(index >= 0 ? index : (this.selectedIndex || 0))
    }
    this.onCache = () => {
      this.restore()
      // Turbo can cache on a same-document fragment visit without disconnecting.
      // Its cloned snapshot is expanded; restore the still-live island afterwards.
      this.cacheFrame = requestAnimationFrame(() => {
        if (!this.element.isConnected) return
        this.expandTarget.hidden = false
        this.expandTarget.textContent = this.expanded ? "Show tabs" : "Show all"
        if (!this.expanded) this.select(this.selectedIndex || 0)
      })
    }
    window.addEventListener("hashchange", this.onHash)
    document.addEventListener("turbo:before-cache", this.onCache)
    this.select(Math.max(0, this.fragmentIndex()))
  }

  disconnect() {
    window.removeEventListener("hashchange", this.onHash)
    document.removeEventListener("turbo:before-cache", this.onCache)
    if (this.cacheFrame) cancelAnimationFrame(this.cacheFrame)
    this.restore()
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
    this.select(index)
    if (location.hash !== event.currentTarget.hash) history.pushState(null, "", event.currentTarget.hash)
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
    this.select(index)
    history.replaceState(null, "", this.tabTargets[index].hash)
  }

  select(index) {
    this.selectedIndex = index
    this.expandTarget.hidden = false
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
      panel.tabIndex = 0
      if (i === index) panel.removeAttribute("hidden")
      else panel.setAttribute("hidden", "until-found")
    })
    this.element.dataset.tabbed = "true"
  }

  found(event) {
    if (!this.enhanced || this.expanded) return
    this.select(this.panelTargets.indexOf(event.currentTarget))
  }

  expand() {
    this.expanded = !this.expanded
    this.expandTarget.textContent = this.expanded ? "Show tabs" : "Show all"
    if (this.expanded) this.reveal()
    else this.select(Math.max(0, this.fragmentIndex()))
  }

  reveal() {
    delete this.element.dataset.tabbed
    this.listTarget.removeAttribute("role")
    this.tabTargets.forEach(tab => {
      for (const name of ["role", "aria-controls", "aria-selected", "tabindex"]) tab.removeAttribute(name)
    })
    this.panelTargets.forEach(panel => {
      for (const name of ["hidden", "role", "tabindex"]) panel.removeAttribute(name)
      panel.setAttribute("aria-labelledby", `${panel.id}-heading`)
    })
  }

  restore() {
    if (!this.enhanced) return
    this.reveal()
    this.expandTarget.hidden = true
    this.expandTarget.textContent = "Show all"
  }
}
