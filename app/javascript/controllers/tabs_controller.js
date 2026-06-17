import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "tab", "content" ]

  switch(event) {
    const tabName = event.currentTarget.dataset.tabName

    this.tabTargets.forEach(tab => {
      tab.classList.toggle("active", tab === event.currentTarget)
    })

    this.contentTargets.forEach(content => {
      content.classList.toggle("hidden", content.dataset.tabName !== tabName)
    })
  }
}
