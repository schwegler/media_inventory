import { Controller } from "@hotwired/stimulus"

// Tracking writes and filter reads can finish in either order. Keep navigation
// intent outside the replaceable frame, and refresh that view after each write.
export default class extends Controller {
  connect() {
    this.owner = crypto.randomUUID()
    this.sequence = 0
    this.refreshScheduled = false
    this.mutations = new Set()
    this.formTokens = new WeakMap()
    this.desiredURL = new URL(window.location.href)
    this.requestHandler = event => this.request(event)
    this.responseHandler = event => this.response(event)
    this.intentHandler = event => this.intent(event)
    this.renderHandler = event => this.render(event)
    this.endHandler = event => this.mutations.delete(this.formTokens.get(event.detail.formSubmission.formElement))
    this.element.addEventListener("turbo:before-fetch-request", this.requestHandler)
    this.element.addEventListener("series-navigation:intent", this.intentHandler)
    document.addEventListener("turbo:before-fetch-response", this.responseHandler)
    document.addEventListener("turbo:before-frame-render", this.renderHandler)
    document.addEventListener("turbo:submit-end", this.endHandler)
    this.element.dataset.seriesResponseConnected = "true"
  }

  disconnect() {
    this.element.removeEventListener("turbo:before-fetch-request", this.requestHandler)
    this.element.removeEventListener("series-navigation:intent", this.intentHandler)
    document.removeEventListener("turbo:before-fetch-response", this.responseHandler)
    document.removeEventListener("turbo:before-frame-render", this.renderHandler)
    document.removeEventListener("turbo:submit-end", this.endHandler)
    this.mutations.clear()
    this.owner = null
    this.refreshScheduled = false
    delete this.element.dataset.seriesResponseConnected
  }

  get frame() { return this.element.querySelector("#series-entries") }

  intent(event) {
    const form = event.target
    const url = new URL(form.action)
    url.search = new URLSearchParams(new FormData(form)).toString()
    if (url.href === this.desiredURL.href) return
    this.desiredURL = url
    // Invalidate an already received read too, before its deferred frame render.
    this.navigationToken = null
  }

  request(event) {
    const frame = this.frame
    if (!frame || !(event.target === frame || frame.contains(event.target))) return
    const method = event.detail.fetchOptions.method.toUpperCase()
    if (method !== "GET" && !event.target.matches("form.series-entry-track")) return
    const token = `${this.owner}:${++this.sequence}`
    event.detail.fetchOptions.headers["X-Series-Request"] = token
    if (method === "GET") {
      this.navigationToken = token
      this.desiredURL = new URL(event.detail.url)
    } else {
      event.detail.fetchOptions.headers["X-Series-Refresh"] = "true"
      this.mutations.add(token)
      this.formTokens.set(event.target, token)
    }
  }

  response(event) {
    const response = event.detail.fetchResponse
    const token = response.header("X-Series-Request")
    if (!token) return
    if (!token.startsWith(`${this.owner}:`)) { event.preventDefault(); return }
    if (this.mutations.has(token)) {
      if (response.succeeded && response.header("X-Series-Refresh") === "true") this.refresh()
    } else if (token !== this.navigationToken) event.preventDefault()
  }

  render(event) {
    if (event.target !== this.frame) return
    const token = event.detail.newFrame.dataset.seriesRequestToken
    if (token && token !== this.navigationToken) event.detail.render = () => {}
  }

  refresh() {
    if (this.refreshScheduled) return
    this.refreshScheduled = true
    const owner = this.owner
    queueMicrotask(() => {
      if (this.owner !== owner) return
      this.refreshScheduled = false
      if (!this.element.isConnected || !this.frame) return
      const url = this.desiredURL.href
      if (this.frame.src === url) this.frame.reload()
      else this.frame.src = url
    })
  }
}
