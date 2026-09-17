import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "tab", "content" ]

  connect() {
    this.element.dataset.connected = "true"
  }

  switch(event) {
    const selectedTab = event.currentTarget
    const tabName = selectedTab.dataset.tabName

    this.activateTab(selectedTab, tabName)
  }

  keydown(event) {
    const tabs = this.tabTargets
    const currentIndex = tabs.indexOf(event.currentTarget)
    if (currentIndex === -1) return

    let targetIndex = null
    if (event.key === "ArrowRight") {
      targetIndex = (currentIndex + 1) % tabs.length
    } else if (event.key === "ArrowLeft") {
      targetIndex = (currentIndex - 1 + tabs.length) % tabs.length
    } else if (event.key === "Home") {
      targetIndex = 0
    } else if (event.key === "End") {
      targetIndex = tabs.length - 1
    }

    if (targetIndex !== null) {
      event.preventDefault()
      const targetTab = tabs[targetIndex]
      targetTab.focus()
      const tabName = targetTab.dataset.tabName
      this.activateTab(targetTab, tabName)
    }
  }

  activateTab(selectedTab, tabName) {
    this.tabTargets.forEach(tab => {
      const isSelected = tab === selectedTab
      tab.classList.toggle("active", isSelected)
      tab.setAttribute("aria-selected", isSelected ? "true" : "false")
      tab.setAttribute("tabindex", isSelected ? "0" : "-1")
    })

    this.contentTargets.forEach(content => {
      content.classList.toggle("hidden", content.dataset.tabName !== tabName)
    })
  }
}
