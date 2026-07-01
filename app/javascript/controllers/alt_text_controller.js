import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.addBadge()
  }

  addBadge() {
    // Only proceed if it's an image element with alt text
    if (this.element.tagName !== 'IMG' || !this.element.alt) return;
    if (this.element.alt.trim() === '' || this.element.alt.trim().toLowerCase() === 'cover') return;

    // We need a wrapper to position the badge correctly
    if (!this.element.parentNode.classList.contains('alt-text-wrapper')) {
      const wrapper = document.createElement('div')
      wrapper.classList.add('alt-text-wrapper')
      wrapper.style.position = 'relative'
      wrapper.style.display = 'inline-block'

      // Preserve original image's layout behavior
      const computedStyle = window.getComputedStyle(this.element)
      if (computedStyle.display === 'block') {
         wrapper.style.display = 'block'
      }

      this.element.parentNode.insertBefore(wrapper, this.element)
      wrapper.appendChild(this.element)
    }

    const badge = document.createElement('div')
    badge.textContent = 'ALT'
    badge.classList.add('alt-badge')
    badge.style.position = 'absolute'
    badge.style.bottom = '8px'
    badge.style.right = '8px'
    badge.style.backgroundColor = 'rgba(0, 0, 0, 0.7)'
    badge.style.color = '#fff'
    badge.style.padding = '2px 6px'
    badge.style.fontSize = '10px'
    badge.style.fontWeight = 'bold'
    badge.style.borderRadius = '4px'
    badge.style.cursor = 'pointer'
    badge.style.zIndex = '10'
    badge.style.fontFamily = 'system-ui, -apple-system, sans-serif'

    badge.addEventListener('click', (e) => {
      e.preventDefault()
      e.stopPropagation()
      alert(this.element.alt)
    })

    this.element.parentNode.appendChild(badge)
  }
}
