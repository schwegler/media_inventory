import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "tab", "content" ]

  connect() {
    this.element.dataset.connected = "true"
    this.tabTargets[0]?.parentElement?.setAttribute("role", "tablist")
    this.updateAria()
  }

  switch(event) {
    this.activateTab(event.currentTarget)
  }

  activateTab(selectedTab) {
    const tabName = selectedTab.dataset.tabName
    this.tabTargets.forEach(t => t.classList.toggle("active", t === selectedTab))
    this.contentTargets.forEach(c => c.classList.toggle("hidden", c.dataset.tabName !== tabName))
    this.updateAria()
  }

  updateAria() {
    this.tabTargets.forEach(t => {
      const active = t.classList.contains("active")
      t.setAttribute("role", "tab")
      t.setAttribute("aria-selected", active ? "true" : "false")
      t.setAttribute("tabindex", active ? "0" : "-1")
    })
    this.contentTargets.forEach(c => {
      c.setAttribute("role", "tabpanel")
      if (c.classList.contains("hidden")) {
        c.setAttribute("aria-hidden", "true")
      } else {
        c.removeAttribute("aria-hidden")
      }
    })
  }

  keydown(event) {
    const idx = this.tabTargets.indexOf(event.currentTarget)
    let nextIdx
    if (event.key === "ArrowRight") {
      nextIdx = (idx + 1) % this.tabTargets.length
    } else if (event.key === "ArrowLeft") {
      nextIdx = (idx - 1 + this.tabTargets.length) % this.tabTargets.length
    } else if (event.key === "Home") {
      nextIdx = 0
    } else if (event.key === "End") {
      nextIdx = this.tabTargets.length - 1
    } else {
      return
    }

    event.preventDefault()
    const nextTab = this.tabTargets[nextIdx]
    nextTab.focus()
    this.activateTab(nextTab)
  }
}
