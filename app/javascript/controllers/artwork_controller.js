import { Controller } from "@hotwired/stimulus"

// Capture errors, including images which failed before Stimulus connected. Never retry a dead URL.
export default class extends Controller {
  connect() {
    this.labels = new WeakMap()
    this.onLoad = (event) => {
      const img = event.target
      if (img instanceof HTMLImageElement && img.dataset.failed) {
        delete img.dataset.failed
        img.hidden = false
        this.labels.get(img)?.remove()
      }
    }
    this.element.addEventListener("load", this.onLoad, true)
    this.onError = (event) => { if (event.target instanceof HTMLImageElement) this.fallback(event.target) }
    this.element.addEventListener("error", this.onError, true)
    this.element.querySelectorAll("img").forEach(img => {
      if (img.complete && img.naturalWidth === 0) this.fallback(img)
    })
    this.element.dataset.connected = "true"
  }
  disconnect() {
    this.element.removeEventListener("error", this.onError, true)
    this.element.removeEventListener("load", this.onLoad, true)
  }
  fallback(img) {
    if (img.dataset.failed || img.dataset.controller?.includes("avatar")) return
    img.dataset.failed = "true"
    img.hidden = true
    if (img.alt === "") return
    const label = document.createElement("span")
    label.className = "artwork-fallback"
    label.textContent = "Artwork unavailable"
    img.parentElement.append(label)
    this.labels.set(img, label)
  }
}
