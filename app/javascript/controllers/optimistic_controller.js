import { Controller } from "@hotwired/stimulus"

// Turbo sends the form asynchronously and reconciles successful responses.
export default class extends Controller {
  static values = { label: String, selected: Boolean, liked: Boolean }

  start(event) {
    if (this.pending) return
    this.pending = true
    this.button = event.detail.formSubmission.submitter || this.element.querySelector('button, input[type="submit"]')
    if (!this.button) return
    this.snapshot = { html: this.button.innerHTML, liked: this.button.classList.contains("liked"), aria: this.button.getAttribute("aria-label"), value: this.button.value, selected: this.button.classList.contains("is-selected") }
    if (this.hasLabelValue) {
      if (this.button.tagName === "INPUT") this.button.value = this.labelValue
      else this.button.textContent = this.labelValue
    }
    if (this.hasSelectedValue) this.button.classList.toggle("is-selected", this.selectedValue)
    if (this.hasLikedValue) {
      this.button.classList.toggle("liked", this.likedValue)
      const heart = this.button.querySelector(".heart")
      heart?.classList.toggle("is-liked", this.likedValue)
      heart?.classList.toggle("is-unliked", !this.likedValue)
      const count = this.button.querySelector(".likes-count")
      if (count) count.textContent = Math.max(0, Number(count.textContent || 0) + (this.likedValue ? 1 : -1))
      const svg = this.button.querySelector("svg")
      if (svg) svg.setAttribute("fill", this.likedValue ? "#ec4899" : "none")
      this.button.setAttribute("aria-label", this.likedValue ? "Unlike" : "Like")
    }
    this.element.setAttribute("aria-busy", "true")
  }

  response(event) {
    // Keep the current form mounted on HTTP errors so its state can be restored.
    if (!event.detail.fetchResponse.succeeded) event.preventDefault()
  }

  finish(event) {
    this.pending = false
    this.element.removeAttribute("aria-busy")
    if (event.detail.success) return
    if (this.snapshot && this.button) {
      this.button.innerHTML = this.snapshot.html
      this.button.classList.toggle("liked", this.snapshot.liked)
      if (this.snapshot.aria) this.button.setAttribute("aria-label", this.snapshot.aria)
      this.button.value = this.snapshot.value
      this.button.classList.toggle("is-selected", this.snapshot.selected)
    }
    const toast = document.createElement("div")
    toast.className = "alert alert-danger"
    toast.setAttribute("role", "alert")
    toast.textContent = "Could not save your change. Please try again."
    document.getElementById("flash-messages")?.append(toast)
    setTimeout(() => toast.remove(), 8000)
  }
}
