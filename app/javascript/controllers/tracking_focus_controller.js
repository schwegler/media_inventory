import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() { this.element.dataset.trackingReady = "true" }
  remember() { this.submitted = true }

  retain(event) {
    if (!this.submitted && !this.element.contains(document.activeElement)) return
    const targetId = event.target.getAttribute("target")
    const streamTarget = document.getElementById(targetId)
    if (targetId !== this.element.id && !streamTarget?.contains(this.element)) return
    const id = this.element.id
    const sectionId = this.element.closest("section")?.id
    const render = event.detail.render
    event.detail.render = async (stream) => {
      await render(stream)
      const next = document.getElementById(id)?.querySelector("[data-tracking-primary]")
      const fallback = document.getElementById(sectionId)?.querySelector("[data-tracking-primary], h2")
      if (!next && fallback) fallback.tabIndex = -1
      const target = next || fallback
      target?.focus({ preventScroll: true })
    }
  }
}
