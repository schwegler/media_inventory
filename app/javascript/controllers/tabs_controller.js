import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "tab", "content" ]

  connect() {
    this.element.dataset.connected = "true"
    this.updateTabAccessibility()
  }

  switch(event) {
    const tabName = event.currentTarget.dataset.tabName
    this.activateTab(tabName)
  }

  activateTab(tabName) {
    this.tabTargets.forEach(tab => {
      const isActive = tab.dataset.tabName === tabName
      tab.classList.toggle("active", isActive)
      tab.setAttribute("aria-selected", isActive)
      tab.setAttribute("tabindex", isActive ? "0" : "-1")
    })

    this.contentTargets.forEach(content => {
      content.classList.toggle("hidden", content.dataset.tabName !== tabName)
    })
  }

  keydown(event) {
    const tabs = this.tabTargets
    const currentIndex = tabs.indexOf(event.currentTarget)

    let nextIndex
    switch (event.key) {
      case "ArrowRight":
        nextIndex = (currentIndex + 1) % tabs.length
        break
      case "ArrowLeft":
        nextIndex = (currentIndex - 1 + tabs.length) % tabs.length
        break
      case "Home":
        nextIndex = 0
        break
      case "End":
        nextIndex = tabs.length - 1
        break
      default:
        return
    }

    event.preventDefault()
    const nextTab = tabs[nextIndex]
    nextTab.focus()
    this.activateTab(nextTab.dataset.tabName)
  }

  updateTabAccessibility() {
    this.tabTargets.forEach((tab, index) => {
      const isActive = tab.classList.contains("active")
      tab.setAttribute("aria-selected", isActive)
      tab.setAttribute("tabindex", isActive ? "0" : "-1")
    })
  }
}
