import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "tab", "content" ]

  switch(event) {
    const tabName = event.currentTarget.dataset.tabName

    this.tabTargets.forEach(tab => {
      const isActive = tab === event.currentTarget
      tab.classList.toggle("active", isActive)
      tab.setAttribute("aria-selected", isActive ? "true" : "false")
    })

    this.contentTargets.forEach(content => {
      content.classList.toggle("hidden", content.dataset.tabName !== tabName)
    })
  }
}
