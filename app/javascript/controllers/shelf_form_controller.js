import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["errors", "leaveDialog"]
  connect() { this.dirty = false; this.submitting = false; if (this.hasErrorsTarget) this.errorsTarget.focus() }
  changed() { this.dirty = true }
  beforeVisit(event) {
    if (!this.dirty || this.submitting) return
    event.preventDefault(); this.destination = event.detail.url; this.opener = document.activeElement
    this.leaveDialogTarget.showModal()
  }
  stay() { this.leaveDialogTarget.close(); this.opener?.focus() }
  leave() { this.dirty = false; this.leaveDialogTarget.close(); window.Turbo.visit(this.destination) }
  beforeUnload(event) { if (this.dirty && !this.submitting) { event.preventDefault(); event.returnValue = "" } }
  submit(event) { if (this.submitting) { event.preventDefault(); return } this.submitting = true }
  submitted(event) { this.submitting = false; if (event.detail.success) this.dirty = false }
}
