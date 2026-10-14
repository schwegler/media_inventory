import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { label: String }

  open(event) {
    if (event.ctrlKey || event.metaKey || event.shiftKey || event.altKey) return
    event.preventDefault()
    this.dialog = document.createElement("dialog")
    this.dialog.className = "artwork-lightbox"
    this.dialog.setAttribute("aria-label", this.labelValue)
    const close = document.createElement("button")
    close.type = "button"
    close.textContent = "Close"
    close.addEventListener("click", () => this.dialog.close())
    const image = document.createElement("img")
    image.src = this.element.href
    image.alt = this.labelValue
    const original = document.createElement("a")
    original.href = this.element.href
    original.textContent = "Open full-size image"
    original.target = "_blank"
    original.rel = "noopener"
    this.dialog.append(close, original, image)
    this.dialog.addEventListener("click", event => {
      if (event.target === this.dialog) this.dialog.close()
    })
    this.dialog.addEventListener("close", () => {
      this.dialog.remove()
      this.element.focus()
    })
    document.body.append(this.dialog)
    this.dialog.showModal()
  }

  disconnect() {
    this.dialog?.remove()
  }
}
