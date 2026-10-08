import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "content"]
  connect() {
    const list = this.tabTarget.parentElement
    list.setAttribute("role", "tablist")
    list.setAttribute("aria-label", list.classList.contains("profile-tabs") ? "Profile sections" : "Sign in method")
    this.tabTargets.forEach((tab, index) => {
      tab.type = "button"
      tab.id ||= `tabs-${this.element.id || this.tabTargets[0].dataset.tabName}-${index}`
      tab.setAttribute("role", "tab")
      const panel = this.contentTargets.find(content => content.dataset.tabName === tab.dataset.tabName)
      if (panel) {
        panel.id ||= `${tab.id}-panel`
        panel.setAttribute("role", "tabpanel")
        panel.setAttribute("aria-labelledby", tab.id)
        tab.setAttribute("aria-controls", panel.id)
      }
    })
    this.onKeydown = (event) => this.keydown(event)
    list.addEventListener("keydown", this.onKeydown)
    this.list = list
    const requested = new URL(window.location.href).searchParams.get("tab")
    this.activate(this.tabTargets.find(tab => tab.dataset.tabName === requested) || this.tabTargets.find(tab => tab.classList.contains("active")) || this.tabTarget)
    this.element.dataset.connected = "true"
  }
  disconnect() { this.list?.removeEventListener("keydown", this.onKeydown) }
  switch(event) { this.activate(event.currentTarget) }
  activate(selected) {
    this.tabTargets.forEach(tab => {
      const active = tab === selected
      tab.classList.toggle("active", active)
      tab.setAttribute("aria-selected", String(active))
      tab.tabIndex = active ? 0 : -1
    })
    this.contentTargets.forEach(content => {
      const active = content.dataset.tabName === selected.dataset.tabName
      content.classList.toggle("hidden", !active)
      content.hidden = !active
    })
  }
  keydown(event) {
    const index = this.tabTargets.indexOf(event.target)
    if (index === -1 || !["ArrowLeft", "ArrowRight", "Home", "End"].includes(event.key)) return
    event.preventDefault()
    const count = this.tabTargets.length
    const next = event.key === "Home" ? 0 : event.key === "End" ? count - 1 : (index + (event.key === "ArrowRight" ? 1 : -1) + count) % count
    this.activate(this.tabTargets[next])
    this.tabTargets[next].focus()
  }
}
