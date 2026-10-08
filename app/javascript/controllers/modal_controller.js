import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["overlay"]
  connect() {
    this.opener = window.troveModalOpener || document.activeElement
    this.dialog = this.element.querySelector(".modal-container")
    if (!this.dialog) return
    this.dialog.setAttribute("role", "dialog")
    this.dialog.setAttribute("aria-modal", "true")
    this.dialog.setAttribute("aria-label", this.dialog.querySelector("h2")?.textContent || "Add to library")
    document.body.style.overflow = "hidden"
    this.onKeydown = event => this.trap(event)
    this.element.addEventListener("keydown", this.onKeydown)
    this.background = [...document.body.children].filter(el => !el.inert && !el.contains(this.element) && !["SCRIPT", "LINK"].includes(el.tagName))
    this.background.forEach(el => { el.inert = true; el.dataset.modalInert = "true" })
    requestAnimationFrame(() => this.focusables()[0]?.focus())
    this.element.dataset.connected = "true"
  }
  disconnect() {
    document.body.style.overflow = ""
    this.element.removeEventListener("keydown", this.onKeydown)
    this.background?.forEach(el => { el.inert = false; delete el.dataset.modalInert })
    if (this.opener?.isConnected) this.opener.focus()
  }
  focusables() {
    return [...this.element.querySelectorAll("a[href], button, input:not([type='hidden']), select, textarea, [tabindex='0']")].filter(el => !el.disabled && el.getClientRects().length)
  }
  trap(event) {
    if (event.key !== "Tab") return
    const controls = this.focusables()
    const first = controls[0], last = controls[controls.length - 1]
    if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last?.focus() }
    else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first?.focus() }
  }
  close(event) {
    event.preventDefault()
    const frame = document.querySelector("turbo-frame#modal")
    if (frame) { frame.innerHTML = ""; frame.removeAttribute("src") }
    document.body.style.overflow = ""
  }
  closeOnBackdrop(event) { if (event.target === this.overlayTarget) this.close(event) }
  closeOnEsc(event) { if (event.key === "Escape") this.close(event) }
}
