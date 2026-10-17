import { Controller } from "@hotwired/stimulus"
import { renderShelfImage, shelfImageAltText, SHELF_THEMES } from "controllers/shelf_image"

export default class extends Controller {
  static targets = ["slots", "dialog", "query", "results", "status", "canvas", "altText", "altTextDetails"]
  static values = { picks: Array, url: String, search: String, handle: String, category: String, shelves: Array, overview: Boolean, headline: String, owner: Boolean, previewCategory: String, previewSignature: String, previewStored: Boolean, previewTheme: String }

  connect() {
    this.picks = this.picksValue; this.dirty = false; this.imageFormat = this.element.querySelector('[name="shelf-format"]:checked')?.value || "landscape"
    this.imageTheme = this.element.dataset.shelfTheme
    if (!new URL(window.location.href).searchParams.has("theme")) {
      try { this.imageTheme = localStorage.getItem("trove-shelf-theme") || this.imageTheme } catch { /* Storage can be disabled. */ }
    }
    if (!SHELF_THEMES[this.imageTheme]) this.imageTheme = "midnight"
    if (this.previewStoredValue) this.storedPreview = `${this.previewSignatureValue}:${this.previewThemeValue}`
    this.applyTheme(); this.render()
    this.guard = event => { if (this.dirty) { event.preventDefault(); event.returnValue = "" } }
    this.visitGuard = event => { if (this.dirty && !window.confirm("Leave without saving your shelf?")) event.preventDefault() }
    this.onDialogClose = () => { const opener = this.opener; this.opener = null; if (opener && typeof opener.focus === "function" && opener.isConnected) opener.focus() }
    if (this.hasDialogTarget) this.dialogTarget.addEventListener("close", this.onDialogClose)
    window.addEventListener("beforeunload", this.guard)
    document.addEventListener("turbo:before-visit", this.visitGuard)
    this.element.dataset.connected = "true"
  }
  disconnect() {
    clearTimeout(this.timer); this.abort?.abort(); window.removeEventListener("beforeunload", this.guard); document.removeEventListener("turbo:before-visit", this.visitGuard)
    if (this.hasDialogTarget) this.dialogTarget.removeEventListener("close", this.onDialogClose)
  }
  button(text, action, label) {
    const button = document.createElement("button")
    button.type = "button"; button.textContent = text
    if (["←", "→"].includes(text)) {
      const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg")
      svg.setAttribute("viewBox", "0 0 24 24"); svg.setAttribute("aria-hidden", "true")
      const path = document.createElementNS("http://www.w3.org/2000/svg", "path")
      path.setAttribute("d", text === "←" ? "M20 12H5m6-6-6 6 6 6" : "M4 12h15m-6-6 6 6-6 6")
      svg.append(path); button.replaceChildren(svg)
    }
    if (label) button.setAttribute("aria-label", label)
    button.addEventListener("click", action)
    return button
  }
  render() {
    if (!this.hasSlotsTarget) { this.schedulePreview(); return }
    const owner = this.slotsTarget.dataset.owner === "true"
    this.slotsTarget.replaceChildren()
    for (let index = 0; index < 5; index++) {
      const pick = this.picks[index], slot = document.createElement("article")
      slot.className = "shelf-slot"; slot.dataset.mediaType = pick?.type || ""
      const cover = owner ? this.button(pick ? "Replace" : "+ Add favorite", event => this.open(index, event), `Choose favorite ${index + 1}`) : document.createElement(pick?.url ? "a" : "div")
      if (!owner && pick?.url) cover.href = pick.url
      cover.className = "shelf-pick"
      if (pick?.cover) { const img = new Image(); img.src = pick.cover; img.alt = pick.title; cover.replaceChildren(img) }
      else if (pick) cover.textContent = pick.title
      else if (!owner) cover.textContent = "Not picked yet"
      const title = document.createElement("h3"); title.textContent = `${index + 1}. ${pick?.title || "Your next favorite"}`
      if (pick?.url) {
        const link = document.createElement("a"); link.href = pick.url; link.textContent = title.textContent; title.replaceChildren(link)
      }
      slot.append(cover, title)
      if (owner && pick) {
        const controls = document.createElement("div"); controls.className = "shelf-controls"
        const up = this.button("←", () => this.move(index, -1), `Move ${pick.title} earlier`); up.disabled = index === 0
        const down = this.button("→", () => this.move(index, 1), `Move ${pick.title} later`); down.disabled = index === this.picks.length - 1
        controls.append(up, down, this.button("Remove", () => { this.picks.splice(index, 1); this.changed() }, `Remove ${pick.title} from shelf`))
        slot.append(controls)
      }
      this.slotsTarget.append(slot)
    }
    this.schedulePreview()
  }
  changed() { this.dirty = true; this.statusTarget.textContent = "Unsaved changes"; this.render() }
  move(index, direction) { [this.picks[index], this.picks[index + direction]] = [this.picks[index + direction], this.picks[index]]; this.changed() }
  open(index, event) { this.slot = Math.min(index, this.picks.length); this.opener = event?.currentTarget || document.activeElement; this.dialogTarget.showModal(); this.queryTarget.value = ""; this.resultsTarget.textContent = "Type at least two characters to search."; this.queryTarget.focus() }
  close() { this.dialogTarget.close() }
  search() {
    clearTimeout(this.timer); this.abort?.abort()
    const query = this.queryTarget.value.trim()
    if (query.length < 2) { this.resultsTarget.textContent = "Type at least two characters to search."; return }
    this.resultsTarget.textContent = "Searching…"
    this.timer = setTimeout(async () => {
      this.abort = new AbortController()
      try {
        const response = await fetch(`${this.searchValue}&q=${encodeURIComponent(query)}`, { signal: this.abort.signal })
        if (!response.ok) throw new Error("Search failed")
        const results = await response.json(); this.resultsTarget.replaceChildren()
        results.forEach(pick => {
          const selected = this.picks.some(p => p.type === pick.type && p.id === pick.id)
          const result = this.button(`${pick.title} · ${pick.type} ${pick.year || ""}${selected ? " · Already selected" : ""}`, () => { this.picks[this.slot] = pick; this.changed(); this.close() })
          result.className = "shelf-result"; result.disabled = selected
          if (pick.cover) { const img = new Image(); img.src = pick.cover; img.alt = ""; result.prepend(img) }
          this.resultsTarget.append(result)
        })
        if (!results.length) this.resultsTarget.textContent = "No matches. Try a different title."
      } catch (error) { if (error.name !== "AbortError") this.resultsTarget.textContent = "Search unavailable. Please try again." }
    }, 200)
  }
  async save() {
    this.statusTarget.textContent = "Saving…"
    try {
      const response = await fetch(this.urlValue, { method: "PATCH", headers: { "Content-Type": "application/json", "Accept": "application/json", "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || "" }, body: JSON.stringify({ picks: this.picks.map(({ id, type }) => ({ id, type })) }) })
      const result = await response.json()
      if (!response.ok) throw new Error(result.error || "Save failed")
      this.dirty = false; this.previewSignatureValue = result.preview_signature; this.render(); this.statusTarget.textContent = "Shelf saved. Your public shelf is ready to share."
    } catch (error) { this.statusTarget.textContent = error.message }
  }
  theme(event) {
    this.imageTheme = event.target.value
    try { localStorage.setItem("trove-shelf-theme", this.imageTheme) } catch { /* Presentation still works without storage. */ }
    this.applyTheme(); this.schedulePreview()
  }
  applyTheme() {
    this.element.dataset.shelfTheme = this.imageTheme
    this.element.querySelectorAll('[name="shelf-theme"]').forEach(input => { input.checked = input.value === this.imageTheme })
    this.element.querySelectorAll('[data-shelf-link]').forEach(link => {
      const url = new URL(link.href); url.searchParams.set("theme", this.imageTheme); link.href = url.href
    })
  }
  format(event) { this.imageFormat = event.target.value; this.schedulePreview() }
  async copyLink() {
    if (this.dirty) { this.statusTarget.textContent = "Save your changes before sharing your public shelf."; return }
    const url = new URL(window.location.href); url.searchParams.set("theme", this.imageTheme)
    try { await navigator.clipboard.writeText(url.href); this.statusTarget.textContent = "Shelf link copied, including your theme." }
    catch { this.statusTarget.textContent = `Copy this shelf link: ${url.href}` }
  }
  imageOptions() {
    return { picks: [...this.picks], shelves: this.shelvesValue,
      overview: this.overviewValue, headline: this.headlineValue, theme: this.imageTheme, format: this.imageFormat,
      handle: this.handleValue, category: this.categoryValue }
  }
  async copyAltText() {
    if (this.dirty) { this.statusTarget.textContent = "Save your changes before copying alt text so it matches your share image."; return }
    const description = shelfImageAltText(this.imageOptions())
    this.altTextTarget.value = description
    try { await navigator.clipboard.writeText(description); this.statusTarget.textContent = "Image alt text copied." }
    catch {
      this.altTextDetailsTarget.open = true
      this.altTextTarget.focus(); this.altTextTarget.select()
      this.statusTarget.textContent = "Clipboard unavailable. Select and copy the image alt text below."
    }
  }
  schedulePreview() {
    const description = shelfImageAltText(this.imageOptions())
    this.altTextTarget.value = description
    this.canvasTarget.setAttribute("aria-label", description)
    if (this.canvasTarget.closest("details")?.open) this.preview().catch(() => {
      this.statusTarget.textContent = "Preview unavailable. Your saved shelf is safe. Please try again."
    })
  }
  previewVisible(event) { if (event.target.open) this.schedulePreview() }
  async preview() {
    const version = this.version = (this.version || 0) + 1
    const canvas = document.createElement("canvas")
    const options = this.imageOptions()
    const description = shelfImageAltText(options)
    this.altTextTarget.value = description
    this.canvasTarget.setAttribute("aria-label", description)
    await renderShelfImage(canvas, options)
    if (version !== this.version || !this.element.isConnected) return
    this.canvasTarget.width = canvas.width; this.canvasTarget.height = canvas.height
    this.canvasTarget.getContext("2d").drawImage(canvas, 0, 0)
    return canvas
  }
  async publishPreview(event) {
    if (!this.ownerValue || this.publishing) return
    if (this.dirty) { this.statusTarget.textContent = "Save your shelf before publishing a share preview."; return }
    const button = event.currentTarget
    this.publishing = true; button.disabled = true; button.setAttribute("aria-busy", "true")
    this.statusTarget.textContent = "Publishing your share preview…"
    try {
      const saved = await this.storePreview()
      this.statusTarget.textContent = saved ? "Share preview published. Your public shelf link is ready." : "Preview changed or could not be saved. Please try again."
    } catch { this.statusTarget.textContent = "Could not publish the preview. Your saved favorites are safe. Please try again." }
    finally { this.publishing = false; button.disabled = false; button.removeAttribute("aria-busy") }
  }
  async storePreview() {
    const signature = this.previewSignatureValue, theme = this.imageTheme
    const key = `${signature}:${theme}`
    if (this.storedPreview === key) return true
    const canvas = document.createElement("canvas")
    await renderShelfImage(canvas, { ...this.imageOptions(), theme, format: "landscape" })
    if (this.dirty || !this.element.isConnected || signature !== this.previewSignatureValue || theme !== this.imageTheme) return false
    const blob = await new Promise(resolve => canvas.toBlob(resolve, "image/png"))
    if (!blob) return false
    const body = new FormData()
    body.append("preview_image", blob, "shelf.png"); body.append("theme", theme)
    body.append("preview_category", this.previewCategoryValue); body.append("preview_signature", signature)
    const response = await fetch(this.urlValue, { method: "PATCH", body,
      headers: { "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || "" } })
    if (response.ok) this.storedPreview = key
    return response.ok
  }
  async download() {
    if (this.dirty) { this.statusTarget.textContent = "Save your changes before downloading so the image matches your public shelf."; return }
    this.statusTarget.textContent = "Preparing your share image…"
    const canvas = await this.preview()
    if (!canvas) { this.statusTarget.textContent = "Presentation changed. Download again to use the latest version."; return }
    canvas.toBlob(blob => {
      if (!blob) { this.statusTarget.textContent = "Image export failed. Please try again."; return }
      const url = URL.createObjectURL(blob), link = document.createElement("a")
      link.href = url; link.download = `trove-${this.handleValue}-${this.overviewValue ? "all-shelves" : this.categoryValue.replaceAll(" ", "-")}-${this.imageTheme}-${this.imageFormat}.png`; link.click()
      setTimeout(() => URL.revokeObjectURL(url), 1000); this.statusTarget.textContent = "PNG downloaded. Ready to share."
    }, "image/png")
  }
}
