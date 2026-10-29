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
    window.addEventListener("hashchange", this.onScroll)
    this.update()
  }

  disconnect() {
    window.removeEventListener("scroll", this.onScroll)
    window.removeEventListener("resize", this.onScroll)
    window.removeEventListener("hashchange", this.onScroll)
    if (this.frame) cancelAnimationFrame(this.frame)
  }

  update() {
    let current = 0
    this.sections.forEach((section, index) => {
      if (section && section.getBoundingClientRect().top <= 140) current = index
    })
    // A desktop reading rail shares a row with My Library. Honor the selected
    // fragment when their starts coincide, including clicks with no scroll.
    const anchored = this.links.findIndex(link => link.hash === window.location.hash)
    if (anchored >= 0 && this.sections[anchored] && this.sections[current]) {
      const difference = this.sections[anchored].getBoundingClientRect().top - this.sections[current].getBoundingClientRect().top
      const top = this.sections[anchored].getBoundingClientRect().top
      const atBottom = window.scrollY + window.innerHeight >= document.documentElement.scrollHeight - 2
      if (Math.abs(difference) < 2 || (atBottom && top >= 0 && top < window.innerHeight)) current = anchored
    }
    this.links.forEach((link, index) => {
      if (index === current) link.setAttribute("aria-current", "location")
      else link.removeAttribute("aria-current")
    })
  }
}
