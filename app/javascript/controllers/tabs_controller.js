import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "tab", "content" ]

  connect() {
    this.element.dataset.connected = "true"
    this.keydownHandler = this.keydown.bind(this)
    this.element.addEventListener("keydown", this.keydownHandler)
    this.setupAria()
  }

  disconnect() {
    this.element.removeEventListener("keydown", this.keydownHandler)
  }

  setupAria() {
    const tabList = this.tabTargets[0]?.parentElement
    if (tabList) tabList.setAttribute("role", "tablist")

    this.tabTargets.forEach(tab => {
      tab.setAttribute("role", "tab")
      const tabName = tab.dataset.tabName
      tab.setAttribute("id", `tab-${tabName}`)

      const isActive = tab.classList.contains("active")
      tab.setAttribute("aria-selected", isActive ? "true" : "false")
      tab.setAttribute("tabindex", isActive ? "0" : "-1")

      const panel = this.contentTargets.find(c => c.dataset.tabName === tabName)
      if (panel) {
        panel.setAttribute("role", "tabpanel")
        panel.setAttribute("aria-labelledby", `tab-${tabName}`)
      }
    })
  }

  switch(event) {
    const tabName = event.currentTarget.dataset.tabName

    this.tabTargets.forEach(tab => {
      const isActive = tab === event.currentTarget
      tab.classList.toggle("active", isActive)
      tab.setAttribute("aria-selected", isActive ? "true" : "false")
      tab.setAttribute("tabindex", isActive ? "0" : "-1")
    })

    this.contentTargets.forEach(content => {
      content.classList.toggle("hidden", content.dataset.tabName !== tabName)
    })
  }

  keydown(event) {
    const tab = event.target.closest("[data-tabs-target='tab']")
    if (!tab) return

    const tabs = this.tabTargets
    const index = tabs.indexOf(tab)
    let newIndex

    switch (event.key) {
      case "ArrowRight":
        newIndex = (index + 1) % tabs.length
        break
      case "ArrowLeft":
        newIndex = (index - 1 + tabs.length) % tabs.length
        break
      case "Home":
        newIndex = 0
        break
      case "End":
        newIndex = tabs.length - 1
        break
      default:
        return
    }

    event.preventDefault()
    const targetTab = tabs[newIndex]
    targetTab.focus()
    targetTab.click()
  }
}
