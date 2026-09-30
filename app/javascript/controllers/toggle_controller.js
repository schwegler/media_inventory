import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="toggle"
export default class extends Controller {
  static targets = ["element", "trigger", "input"]
  static classes = ["hidden"]

  connect() {
    this.element.dataset.connected = "true"
    this.keydownHandler = this.keydown.bind(this)
    this.element.addEventListener("keydown", this.keydownHandler)
  }

  disconnect() {
    if (this.element && this.keydownHandler) {
      this.element.removeEventListener("keydown", this.keydownHandler)
    }
  }

  keydown(event) {
    if (event.key === "Escape") {
      const anyVisible = this.elementTargets.some(
        (el) => !el.classList.contains(this.hiddenClass)
      )
      if (anyVisible) {
        event.preventDefault()
        event.stopPropagation()
        this.hide(event)
      }
    }
  }

  toggle(event) {
    if (event) event.preventDefault()
    this.elementTargets.forEach((el) => {
      const isVisible = el.classList.toggle(this.hiddenClass) === false
      this.updateState(isVisible, el)
    })
  }

  hide(event) {
    if (event) event.preventDefault()
    this.elementTargets.forEach((el) => el.classList.add(this.hiddenClass))
    this.updateState(false)
  }

  updateState(isVisible, container = null) {
    if (this.hasTriggerTarget) {
      this.triggerTargets.forEach(t => t.setAttribute("aria-expanded", isVisible ? "true" : "false"))
    }
    if (isVisible && container) {
      const input = this.hasInputTarget ? this.inputTargets.find(i => container.contains(i)) : null
      const targetInput = input || container.querySelector("input:not([type='hidden']), textarea, select")
      if (targetInput) targetInput.focus()
    } else if (!isVisible && this.hasTriggerTarget) {
      this.triggerTarget.focus()
    }
  }
}
