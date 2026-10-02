import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "tab", "content" ]

  connect() {
    this.element.dataset.connected = "true"
    if (this.hasTabTarget) {
      const activeTab = this.tabTargets.find(tab => tab.classList.contains("active") || tab.getAttribute("aria-selected") === "true") || this.tabTargets[0]
      this.activateTab(activeTab)
    }
  }

  switch(event) {
    this.activateTab(event.currentTarget)
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
      this.activateTab(targetTab)
    }
  }

  activateTab(targetTab) {
    const tabName = targetTab.dataset.tabName

    this.tabTargets.forEach(tab => {
      const isCurrent = tab === targetTab
      tab.classList.toggle("active", isCurrent)
      tab.setAttribute("aria-selected", isCurrent ? "true" : "false")
      tab.setAttribute("tabindex", isCurrent ? "0" : "-1")
    })

    this.contentTargets.forEach(content => {
      const isCurrent = content.dataset.tabName === tabName
      content.classList.toggle("hidden", !isCurrent)
    })
  }
}
