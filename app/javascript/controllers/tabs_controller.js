import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "tab", "content" ]

  connect() {
    const uniqueId = Math.random().toString(36).substring(2, 11)
    const tablist = this.tabTargets[0]?.parentElement
    if (tablist) {
      tablist.setAttribute("role", "tablist")
    }

    this.tabTargets.forEach((tab) => {
      const isActive = tab.classList.contains("active")
      const tabName = tab.dataset.tabName
      const panel = this.contentTargets.find(c => c.dataset.tabName === tabName)

      tab.setAttribute("role", "tab")
      tab.setAttribute("aria-selected", isActive ? "true" : "false")
      tab.setAttribute("tabindex", isActive ? "0" : "-1")
      tab.setAttribute("id", `tab-${uniqueId}-${tabName}`)

      if (panel) {
        tab.setAttribute("aria-controls", `panel-${uniqueId}-${tabName}`)
        panel.setAttribute("role", "tabpanel")
        panel.setAttribute("id", `panel-${uniqueId}-${tabName}`)
        panel.setAttribute("aria-labelledby", `tab-${uniqueId}-${tabName}`)
      }

      tab.addEventListener("keydown", this.handleKeydown.bind(this))
    })

    this.element.dataset.connected = "true"
  }

  switch(event) {
    this.activate(event.currentTarget)
  }

  activate(tab) {
    const tabName = tab.dataset.tabName

    this.tabTargets.forEach(t => {
      const active = t === tab
      t.classList.toggle("active", active)
      t.setAttribute("aria-selected", active ? "true" : "false")
      t.setAttribute("tabindex", active ? "0" : "-1")
      if (active) t.focus()
    })

    this.contentTargets.forEach(content => {
      content.classList.toggle("hidden", content.dataset.tabName !== tabName)
    })
  }

  handleKeydown(event) {
    const tabs = this.tabTargets
    const index = tabs.indexOf(event.currentTarget)
    let nextIndex

    if (event.key === "ArrowRight" || event.key === "ArrowDown") {
      nextIndex = (index + 1) % tabs.length
    } else if (event.key === "ArrowLeft" || event.key === "ArrowUp") {
      nextIndex = (index - 1 + tabs.length) % tabs.length
    } else if (event.key === "Home") {
      nextIndex = 0
    } else if (event.key === "End") {
      nextIndex = tabs.length - 1
    } else {
      return
    }

    event.preventDefault()
    this.activate(tabs[nextIndex])
  }
}
