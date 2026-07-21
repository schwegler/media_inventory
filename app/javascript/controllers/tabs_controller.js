import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "tab", "content" ]

  connect() {
    this.keydownHandler = this.handleKeydown.bind(this)
    this.element.addEventListener("keydown", this.keydownHandler)
    this.updateAria()
    this.element.dataset.connected = "true"
  }

  disconnect() {
    this.element.removeEventListener("keydown", this.keydownHandler)
  }

  switch(event) {
    const tabName = event.currentTarget.dataset.tabName
    this.activate(tabName)
  }

  activate(tabName) {
    this.tabTargets.forEach(tab => {
      tab.classList.toggle("active", tab.dataset.tabName === tabName)
    })

    this.contentTargets.forEach(content => {
      content.classList.toggle("hidden", content.dataset.tabName !== tabName)
    })

    this.updateAria()
  }

  updateAria() {
    this.tabTargets.forEach(tab => {
      const isActive = tab.classList.contains("active")
      tab.setAttribute("role", "tab")
      tab.setAttribute("aria-selected", isActive ? "true" : "false")
      tab.setAttribute("tabindex", isActive ? "0" : "-1")
    })

    this.contentTargets.forEach(content => {
      const isActive = !content.classList.contains("hidden")
      content.setAttribute("role", "tabpanel")
      if (isActive) {
        content.setAttribute("tabindex", "0")
      } else {
        content.removeAttribute("tabindex")
      }
    })
  }

  handleKeydown(event) {
    if (!this.tabTargets.includes(event.target)) return

    const tabs = this.tabTargets
    const index = tabs.indexOf(event.target)
    let nextIndex = -1

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
    const nextTab = tabs[nextIndex]
    this.activate(nextTab.dataset.tabName)
    nextTab.focus()
  }
}
