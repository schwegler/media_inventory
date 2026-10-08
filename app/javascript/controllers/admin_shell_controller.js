import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["search"]

  connect() {
    if (window.matchMedia("(max-width: 800px)").matches) {
      this.element.querySelectorAll(".nav-group").forEach((group) => {
        group.open = false
      })
    }
    this.shortcut = (event) => {
      if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "k") {
        event.preventDefault()
        this.searchTarget.focus()
        this.searchTarget.select()
      }
    }
    document.addEventListener("keydown", this.shortcut)
    this.element.querySelectorAll("img[data-admin-artwork]").forEach((image) => {
      const fallback = () => { image.hidden = true }
      image.addEventListener("error", fallback, { once: true })
      if (image.complete && image.naturalWidth === 0) fallback()
    })
  }

  disconnect() { document.removeEventListener("keydown", this.shortcut) }
}
