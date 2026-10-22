import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { label: String }

  connect() {
    this.element.dataset.connected = "true"
  }

  open(event) {
    if (event.ctrlKey || event.metaKey || event.shiftKey || event.altKey) return
    event.preventDefault()
    if (this.dialog?.open) return

    this.listeners = new AbortController()
    const options = { signal: this.listeners.signal }
    const dialog = document.createElement("dialog")
    this.dialog = dialog
    dialog.className = "artwork-lightbox"
    dialog.dataset.state = "loading"
    dialog.setAttribute("aria-label", this.labelValue)

    const toolbar = document.createElement("div")
    toolbar.className = "artwork-lightbox-toolbar"
    const caption = document.createElement("p")
    caption.className = "artwork-lightbox-caption"
    caption.textContent = this.labelValue
    caption.title = this.labelValue
    const actions = document.createElement("div")
    actions.className = "artwork-lightbox-actions"
    const original = document.createElement("a")
    original.href = this.element.href
    original.textContent = "Full size ↗"
    original.setAttribute("aria-label", "Open full-size image in a new tab")
    original.target = "_blank"
    original.rel = "noopener noreferrer"
    const close = document.createElement("button")
    close.type = "button"
    close.textContent = "×"
    close.setAttribute("aria-label", "Close image lightbox")
    close.title = "Close (Esc)"
    close.addEventListener("click", () => dialog.close(), options)
    actions.append(original, close)
    toolbar.append(caption, actions)

    const stage = document.createElement("div")
    stage.className = "artwork-lightbox-stage"
    stage.setAttribute("aria-busy", "true")
    const status = document.createElement("p")
    status.className = "artwork-lightbox-status"
    status.setAttribute("role", "status")
    status.textContent = "Loading artwork…"
    const image = document.createElement("img")
    image.alt = this.labelValue
    image.hidden = true
    image.addEventListener("load", () => {
      dialog.dataset.state = "loaded"
      stage.setAttribute("aria-busy", "false")
      status.hidden = true
      image.hidden = false
    }, options)
    image.addEventListener("error", () => {
      image.hidden = true
      dialog.dataset.state = "error"
      stage.setAttribute("aria-busy", "false")
      status.textContent = "This image couldn’t load. Try opening the full-size image."
    }, options)
    stage.append(status, image)
    dialog.append(toolbar, stage)
    dialog.addEventListener("click", event => {
      const bounds = dialog.getBoundingClientRect()
      if (event.target === dialog && (event.clientX < bounds.left || event.clientX > bounds.right ||
          event.clientY < bounds.top || event.clientY > bounds.bottom)) dialog.close()
    }, options)
    dialog.addEventListener("keydown", event => {
      if (event.key !== "Tab") return
      const first = original, last = close
      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault()
        last.focus()
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault()
        first.focus()
      }
    }, options)
    window.addEventListener("pagehide", () => this.cleanup(false), options)
    dialog.addEventListener("close", () => this.cleanup(true), options)
    document.addEventListener("turbo:before-cache", () => this.cleanup(false), options)
    document.addEventListener("turbo:before-visit", () => this.cleanup(false), options)
    window.addEventListener("popstate", () => this.cleanup(false), options)

    this.previousOverflow = document.documentElement.style.overflow
    this.previousBodyOverflow = document.body.style.overflow
    document.documentElement.style.overflow = "hidden"
    document.body.style.overflow = "hidden"
    document.body.append(dialog)
    dialog.showModal()
    close.focus()
    image.src = this.element.href
  }

  cleanup(restoreFocus) {
    if (!this.dialog) return

    this.listeners.abort()
    this.dialog.remove()
    this.dialog = null
    document.documentElement.style.overflow = this.previousOverflow
    document.body.style.overflow = this.previousBodyOverflow
    if (restoreFocus && this.element.isConnected) this.element.focus({ preventScroll: true })
  }

  disconnect() {
    this.cleanup(false)
  }
}
