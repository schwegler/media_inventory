import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "content"]

  connect() {
    this.element.dataset.connected = "true"
    this.keydownHandler = this.keydown.bind(this)

    this.tabTargets.forEach((tab) => {
      const isActive = tab.classList.contains("active")
      if (!tab.hasAttribute("role")) tab.setAttribute("role", "tab")
      tab.setAttribute("aria-selected", isActive ? "true" : "false")
      tab.setAttribute("tabindex", isActive ? "0" : "-1")
      tab.addEventListener("keydown", this.keydownHandler)
    })
  }

  disconnect() {
    this.tabTargets.forEach((tab) => tab.removeEventListener("keydown", this.keydownHandler))
  }

  switch(event) {
    if (event) event.preventDefault()
    this.activateTab(event.currentTarget)
  }

  activateTab(targetTab) {
    const tabName = targetTab.dataset.tabName

    this.tabTargets.forEach((tab) => {
      const isCurrent = tab === targetTab
      tab.classList.toggle("active", isCurrent)
      tab.setAttribute("aria-selected", isCurrent ? "true" : "false")
      tab.setAttribute("tabindex", isCurrent ? "0" : "-1")
    })

    this.contentTargets.forEach((content) => {
      const isCurrent = content.dataset.tabName === tabName
      content.classList.toggle("hidden", !isCurrent)
    })
  }

  keydown(event) {
    const tabs = this.tabTargets
    const currentIndex = tabs.indexOf(event.currentTarget)
    if (currentIndex === -1) return

    let targetIndex = null
    if (event.key === "ArrowRight") targetIndex = (currentIndex + 1) % tabs.length
    else if (event.key === "ArrowLeft") targetIndex = (currentIndex - 1 + tabs.length) % tabs.length
    else if (event.key === "Home") targetIndex = 0
    else if (event.key === "End") targetIndex = tabs.length - 1

    if (targetIndex !== null) {
      event.preventDefault()
      const targetTab = tabs[targetIndex]
      targetTab.focus()
      this.activateTab(targetTab)
    }
  }
}
