import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    const summary = this.element.querySelector("#error_explanation")
    if (!summary) return
    summary.setAttribute("role", "alert")
    summary.tabIndex = -1
    this.element.querySelectorAll(".field_with_errors input, .field_with_errors select, .field_with_errors textarea").forEach(input => {
      input.setAttribute("aria-invalid", "true")
      input.setAttribute("aria-describedby", [input.getAttribute("aria-describedby"), summary.id].filter(Boolean).join(" "))
    })
  }
}
