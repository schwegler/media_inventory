import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "content"]

  connect() {
    if (this.hasTabTarget) this.updateAria(this.activeTabName)
  }

  switch(event) {
    const tabName = event.currentTarget.dataset.tabName
    this.tabTargets.forEach(t => t.classList.toggle("active", t.dataset.tabName === tabName))
    this.contentTargets.forEach(c => c.classList.toggle("hidden", c.dataset.tabName !== tabName))
    this.updateAria(tabName)
  }

  updateAria(name) {
    this.tabTargets.forEach(t => {
      const active = t.dataset.tabName === name
      t.setAttribute("aria-selected", active)
      t.setAttribute("tabindex", active ? 0 : -1)
    })
  }

  keydown(e) {
    const tabs = this.tabTargets, i = tabs.indexOf(e.currentTarget)
    let next = i
    if (e.key === "ArrowRight") next = (i + 1) % tabs.length
    else if (e.key === "ArrowLeft") next = (i - 1 + tabs.length) % tabs.length
    else if (e.key === "Home") next = 0
    else if (e.key === "End") next = tabs.length - 1
    else return
    e.preventDefault()
    tabs[next].focus()
    tabs[next].click()
  }

  get activeTabName() {
    const active = this.tabTargets.find(t => t.classList.contains("active"))
    return active ? active.dataset.tabName : this.tabTargets[0].dataset.tabName
  }
}
