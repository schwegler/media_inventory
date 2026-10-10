import { Controller } from "@hotwired/stimulus"

// These are document links, not tabs: every section remains accessible and searchable.
export default class extends Controller {
  connect() {
    this.links = Array.from(this.element.querySelectorAll('a[href^="#"]'))
    this.sections = this.links.map(link => document.getElementById(link.hash.slice(1)))
    this.onScroll = () => {
      if (this.frame) return
      this.frame = requestAnimationFrame(() => { this.frame = null; this.update() })
    }
    window.addEventListener("scroll", this.onScroll, { passive: true })
    window.addEventListener("resize", this.onScroll)
    this.update()
  }

  disconnect() {
    window.removeEventListener("scroll", this.onScroll)
    window.removeEventListener("resize", this.onScroll)
    if (this.frame) cancelAnimationFrame(this.frame)
  }

  update() {
    let current = 0
    this.sections.forEach((section, index) => {
      if (section && section.getBoundingClientRect().top <= 140) current = index
    })
    this.links.forEach((link, index) => {
      if (index === current) link.setAttribute("aria-current", "location")
      else link.removeAttribute("aria-current")
    })
  }
}
