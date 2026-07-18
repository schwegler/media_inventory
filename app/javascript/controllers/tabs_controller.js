import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "tab", "content" ]

  connect() {
    this.updateAriaStates()
  }

  switch(event) {
    const selectedTab = event.currentTarget
    const tabName = selectedTab.dataset.tabName

    this.tabTargets.forEach(tab => {
      tab.classList.toggle("active", tab === selectedTab)
    })

    this.contentTargets.forEach(content => {
      content.classList.toggle("hidden", content.dataset.tabName !== tabName)
    })

    this.updateAriaStates()
  }

  updateAriaStates() {
    this.tabTargets.forEach(tab => {
      const isActive = tab.classList.contains("active")
      tab.setAttribute("aria-selected", isActive ? "true" : "false")
      tab.setAttribute("tabindex", isActive ? "0" : "-1")
    })
  }

  keydown(event) {
    const tabs = this.tabTargets
    const currentIndex = tabs.indexOf(event.currentTarget)
    let newIndex = null

    if (event.key === "ArrowRight") {
      newIndex = (currentIndex + 1) % tabs.length
    } else if (event.key === "ArrowLeft") {
      newIndex = (currentIndex - 1 + tabs.length) % tabs.length
    } else if (event.key === "Home") {
      newIndex = 0
    } else if (event.key === "End") {
      newIndex = tabs.length - 1
    }

    if (newIndex !== null) {
      event.preventDefault()
      const newTab = tabs[newIndex]
      newTab.focus()
      newTab.click()
    }
  }
}
