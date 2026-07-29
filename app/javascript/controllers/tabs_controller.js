import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "tab", "content" ]

  connect() {
    this.initializeTabs()
    this.element.dataset.connected = "true"
  }

  initializeTabs() {
    this.tabTargets.forEach((tab) => {
      const isActive = tab.classList.contains("active")
      tab.setAttribute("role", "tab")
      tab.setAttribute("aria-selected", isActive ? "true" : "false")
      tab.setAttribute("tabindex", isActive ? "0" : "-1")

      const tabName = tab.dataset.tabName
      if (tabName) {
        tab.setAttribute("aria-controls", `panel-${tabName}`)
        tab.setAttribute("id", `tab-${tabName}`)
      }

      // Setup keydown listener for keyboard accessibility
      tab.addEventListener("keydown", this.handleKeydown.bind(this))
    })

    this.contentTargets.forEach((content) => {
      content.setAttribute("role", "tabpanel")
      const tabName = content.dataset.tabName
      if (tabName) {
        content.setAttribute("id", `panel-${tabName}`)
        content.setAttribute("aria-labelledby", `tab-${tabName}`)
      }
    })
  }

  switch(event) {
    const selectedTab = event.currentTarget
    this.activateTab(selectedTab)
  }

  activateTab(selectedTab) {
    const tabName = selectedTab.dataset.tabName

    this.tabTargets.forEach((tab) => {
      const isActive = tab === selectedTab
      tab.classList.toggle("active", isActive)
      tab.setAttribute("aria-selected", isActive ? "true" : "false")
      tab.setAttribute("tabindex", isActive ? "0" : "-1")
    })

    this.contentTargets.forEach((content) => {
      content.classList.toggle("hidden", content.dataset.tabName !== tabName)
    })
  }

  handleKeydown(event) {
    const tabs = this.tabTargets
    const index = tabs.indexOf(event.currentTarget)
    if (index === -1) return

    let newIndex = null

    switch (event.key) {
      case "ArrowRight":
      case "ArrowDown":
        newIndex = (index + 1) % tabs.length
        break
      case "ArrowLeft":
      case "ArrowUp":
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

    if (newIndex !== null) {
      event.preventDefault()
      const targetTab = tabs[newIndex]
      targetTab.focus()
      this.activateTab(targetTab)
    }
  }
}
