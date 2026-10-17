import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() { this.element.dataset.trackingReady = "true" }
  remember() { this.submitted = true }

  retain(event) {
    if (!this.submitted && !this.element.contains(document.activeElement)) return
    if (event.target.getAttribute("target") !== this.element.id) return
    const id = this.element.id
    const sectionId = this.element.closest("section")?.id
    const render = event.detail.render
    event.detail.render = async (stream) => {
      await render(stream)
      const next = document.getElementById(id)?.querySelector("[data-tracking-primary]")
      const fallback = document.getElementById(sectionId)?.querySelector("h2")
      if (!next && fallback) fallback.tabIndex = -1
      const target = next || fallback
      target?.focus({ preventScroll: true })
    }
  }
}
