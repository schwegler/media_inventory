import { Controller } from "@hotwired/stimulus"

// Capture errors, including images which failed before Stimulus connected. Never retry a dead URL.
export default class extends Controller {
  connect() {
    this.labels = new WeakMap()
    this.onLoad = (event) => {
      const img = event.target
      if (img instanceof HTMLImageElement && img.classList.contains("artwork-backdrop")) return
      if (img instanceof HTMLImageElement) img.parentElement?.classList.remove("artwork-pending")
      if (img instanceof HTMLImageElement && img.dataset.failed) {
        delete img.dataset.failed
        img.hidden = false
        this.labels.get(img)?.remove()
      }
      if (img instanceof HTMLImageElement) this.frameGame(img)
    }
    this.element.addEventListener("load", this.onLoad, true)
    this.onError = (event) => { if (event.target instanceof HTMLImageElement) this.fallback(event.target) }
    this.element.addEventListener("error", this.onError, true)
    this.element.querySelectorAll("img").forEach(img => {
      if (img.complete && img.naturalWidth === 0) this.fallback(img)
      else if (img.complete) this.frameGame(img)
      else if (!img.complete && img.closest(".card-2026-cover, .profile-cover")) img.parentElement.classList.add("artwork-pending")
    })
    this.element.dataset.connected = "true"
  }
  disconnect() {
    this.element.removeEventListener("error", this.onError, true)
    this.element.removeEventListener("load", this.onLoad, true)
  }
  frameGame(img) {
    if (img.classList.contains("artwork-backdrop")) return
    const frame = img.closest(".card-2026-cover, .media-cover")
    if (!frame?.closest('[data-media-kind="VideoGame"]')) return

    frame.querySelector(".artwork-backdrop")?.remove()
    delete frame.dataset.artworkLayout
    // Portrait artwork crops naturally; square and landscape art gets a full-bleed backdrop.
    if (!img.naturalHeight || img.naturalWidth / img.naturalHeight < 0.85) return

    const backdrop = img.cloneNode(false)
    backdrop.removeAttribute("id")
    backdrop.removeAttribute("data-controller")
    backdrop.alt = ""
    backdrop.setAttribute("aria-hidden", "true")
    backdrop.className = "artwork-backdrop"
    frame.dataset.artworkLayout = "wide-game"
    frame.prepend(backdrop)
  }
  fallback(img) {
    if (img.classList.contains("artwork-backdrop")) { img.remove(); return }
    if (img.dataset.failed || img.dataset.controller?.includes("avatar")) return
    img.parentElement?.classList.remove("artwork-pending")
    img.dataset.failed = "true"
    const frame = img.closest(".card-2026-cover, .media-cover")
    frame?.querySelector(".artwork-backdrop")?.remove()
    if (frame) delete frame.dataset.artworkLayout
    img.hidden = true
    if (img.alt === "") return
    const label = document.createElement("span")
    label.className = "artwork-fallback"
    label.textContent = "Artwork unavailable"
    img.parentElement.append(label)
    this.labels.set(img, label)
  }
}
