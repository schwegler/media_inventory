import { Controller } from "@hotwired/stimulus"
import { renderShelfImage, shelfImageAltText, SHELF_THEMES, SHELF_STYLES } from "controllers/shelf_image"

export default class extends Controller {
  static targets = ["slots", "dialog", "query", "results", "status", "canvas", "altText", "altTextDetails", "companion", "searchType"]
  static values = { style: Object, assets: Object, picks: Array, publicUrl: String, url: String, search: String, handle: String, category: String, shelves: Array, overview: Boolean, headline: String, owner: Boolean, previewCategory: String, previewSignature: String, capacity: Number, flexible: Boolean, allowedTypes: Array, previewStored: Boolean, previewTheme: String }

  connect() {
    this.picks = this.picksValue; this.dirty = false; this.imageFormat = this.element.querySelector('[name="shelf-format"]:checked')?.value || "portrait"
    this.imageStyle = { layout: "exhibition", texture: "clean", companion: "auto", ...this.styleValue }
    const serverStyle = JSON.stringify(this.imageStyle)
    this.imageTheme = this.element.dataset.shelfTheme
    if (!SHELF_THEMES[this.imageTheme]) this.imageTheme = "midnight"
    if (this.previewStoredValue && JSON.stringify(this.imageStyle) === serverStyle) this.storedPreview = `${this.previewSignatureValue}:${this.previewThemeValue}:${serverStyle}`
    this.applyTheme(); this.render()
    this.guard = event => { if (this.dirty || this.presentationDirty) { event.preventDefault(); event.returnValue = "" } }
    this.visitGuard = event => { if ((this.dirty || this.presentationDirty) && !window.confirm("Leave without saving your shelf?")) event.preventDefault() }
    this.onDialogClose = () => { if (this.dialogTarget.open) return; this.dialogGeneration = (this.dialogGeneration || 0) + 1; const opener = this.opener; this.opener = null; if (opener && typeof opener.focus === "function" && opener.isConnected) opener.focus() }
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
    for (let index = 0; index < (owner && !this.flexibleValue ? 5 : this.picks.length); index++) {
      const pick = this.picks[index], slot = document.createElement("article")
      slot.className = "shelf-slot"; slot.dataset.mediaType = pick?.type || ""
      const cover = owner ? this.button(pick ? "Replace" : "+ Add pick", event => this.open(index, event), `Choose pick ${index + 1}`) : document.createElement(pick?.url ? "a" : "div")
      if (!owner && pick?.url) cover.href = pick.url
      cover.className = "shelf-pick"
      if (pick?.cover) { const img = new Image(); img.src = pick.cover; img.alt = pick.title; cover.replaceChildren(img) }
      else if (pick) cover.textContent = pick.title
      else if (!owner) cover.textContent = "Not picked yet"
      const title = document.createElement("h3"); title.textContent = `${index + 1}. ${pick?.title || "Your next pick"}`
      if (pick?.url) {
        const link = document.createElement("a"); link.href = pick.url; link.textContent = title.textContent; title.replaceChildren(link)
      }
      const type = document.createElement("p"); type.className = "shelf-media-type"
      type.textContent = { Movie: "Movie", TvShow: "TV show", Album: "Album", Book: "Book", Comic: "Comic", VideoGame: "Game" }[pick?.type] || "Selection"
      slot.append(cover, type, title)
      if (owner && pick) {
        const controls = document.createElement("div"); controls.className = "shelf-controls"
        const up = this.button("←", () => this.move(index, -1), `Move ${pick.title} earlier`); up.disabled = index === 0
        const down = this.button("→", () => this.move(index, 1), `Move ${pick.title} later`); down.disabled = index === this.picks.length - 1
        controls.append(up, down, this.button("Remove", () => { this.picks.splice(index, 1); this.changed(); this.focusItem(Math.min(index, this.picks.length - 1)) }, `Remove ${pick.title} from shelf`))
        slot.append(controls)
      }
      this.slotsTarget.append(slot)
    }
    if (owner && this.flexibleValue) {
      const add = this.button("+ Add a title", event => this.open(this.picks.length, event))
      add.className = "shelf-add-title"; add.disabled = this.picks.length >= this.capacityValue; this.slotsTarget.append(add)
      this.element.querySelectorAll('[data-action="favorite-shelf#add"]').forEach(button => { button.disabled = this.picks.length >= this.capacityValue })
    }
    const empty = this.element.querySelector(".shelf-empty-state"); if (empty) empty.hidden = this.picks.length > 0
    const count = this.element.querySelector('[data-shelf-count]')
    if (count) count.textContent = `${this.picks.length} selections`
    this.schedulePreview()
  }
  changed() { this.dirty = true; this.statusTarget.textContent = "Unsaved changes"; this.render() }
  move(index, direction) { [this.picks[index], this.picks[index + direction]] = [this.picks[index + direction], this.picks[index]]; this.changed(); this.focusItem(index + direction) }
  focusItem(index) { this.slotsTarget.querySelectorAll(".shelf-slot")[Math.max(0, index)]?.querySelector("button, a")?.focus() }
  add(event) { this.open(this.picks.length, event) }
  open(index, event) { if (this.flexibleValue && index >= this.picks.length && this.picks.length >= this.capacityValue) { this.statusTarget.textContent = `This shelf holds up to ${this.capacityValue} titles. Remove a title before adding another.`; return }; clearTimeout(this.timer); this.abort?.abort(); this.dialogGeneration = (this.dialogGeneration || 0) + 1; this.slot = Math.min(index, this.picks.length); this.opener = event?.currentTarget || document.activeElement; this.dialogTarget.showModal(); this.queryTarget.value = ""; this.resultsTarget.textContent = "Type at least two characters to search."; requestAnimationFrame(() => this.queryTarget.focus()) }
  close() { this.dialogGeneration = (this.dialogGeneration || 0) + 1; this.dialogTarget.close() }
  localSource() { this.searchSource = "local"; this.updateSourceButtons(); this.search() }
  externalSource() { this.searchSource = "external"; this.updateSourceButtons(); this.search() }
  updateSourceButtons() {
    this.element.querySelectorAll('.shelf-search-sources button').forEach((button, index) => button.setAttribute("aria-pressed", String(index === (this.searchSource === "external" ? 1 : 0))))
  }
  async selectExternal(pick) {
    const slot = this.slot, generation = this.dialogGeneration || 0, type = this.searchTypeTarget.value
    const request = this.externalRequest = (this.externalRequest || 0) + 1
    const current = () => this.element.isConnected && this.dialogTarget.open &&
      generation === (this.dialogGeneration || 0) && request === this.externalRequest
    this.resultsTarget.textContent = "Adding from catalog…"
    try {
      const response = await fetch("/shelves/catalog_items", { method: "POST", headers: { "Content-Type": "application/json", "Accept": "application/json", "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || "" }, body: JSON.stringify({ type, selection: pick.import_selection }) })
      const result = await response.json()
      if (!current()) return
      if (!response.ok) throw new Error(result.error || "Could not add this title")
      if (this.picks.some(p => p.id === result.id && p.type === result.type)) throw new Error("Already selected. Choose another title.")
      this.picks[slot] = result; this.changed(); this.close()
    } catch (error) { if (!current()) return; this.resultsTarget.textContent = `${error.message}. Your search is preserved.`; this.resultsTarget.append(this.button("Retry search", () => this.search())) }
  }
  search() {
    clearTimeout(this.timer); this.abort?.abort()
    const query = this.queryTarget.value.trim()
    if (query.length < 2) { this.resultsTarget.textContent = "Type at least two characters to search."; return }
    this.resultsTarget.textContent = "Searching…"
    this.timer = setTimeout(async () => {
      this.abort = new AbortController()
      try {
        const external = this.searchSource === "external"
        const url = external ? `/media/autocomplete?type=${encodeURIComponent(this.searchTypeTarget.value)}&q=${encodeURIComponent(query)}` : `${this.searchValue.replace(/category=[^&]*/, `category=${encodeURIComponent(this.searchTypeTarget.value.replace(/(^|_)([a-z])/g, (_, prefix, letter) => letter.toUpperCase()))}`)}&q=${encodeURIComponent(query)}`
        const response = await fetch(url, { signal: this.abort.signal })
        if (!response.ok) throw new Error("Search failed")
        const results = await response.json(); this.resultsTarget.replaceChildren()
        results.forEach(pick => {
          if (!external && this.flexibleValue && this.allowedTypesValue?.length && !this.allowedTypesValue.includes(pick.type)) return
          const selected = this.picks.some(p => p.type === pick.type && p.id === pick.id)
          const result = this.button(`${pick.title} · ${pick.type || this.searchTypeTarget.value} ${pick.year || pick.release_year || ""}${selected ? " · Already selected" : ""}`, () => { if (external) this.selectExternal(pick); else { this.picks[this.slot] = pick; this.changed(); this.close() } })
          result.className = "shelf-result"; result.disabled = selected
          if (pick.cover || pick.thumbnail_url) { const img = new Image(); img.src = pick.cover || pick.thumbnail_url; img.alt = ""; result.prepend(img) }
          this.resultsTarget.append(result)
        })
        if (!results.length) this.resultsTarget.textContent = "No matches. Try a different title."
      } catch (error) { if (error.name !== "AbortError") { this.resultsTarget.textContent = "Search unavailable. Your query is preserved."; this.resultsTarget.append(this.button("Retry search", () => this.search())) } }
    }, 200)
  }
  settingsSubmit(event) { if (this.dirty || this.picksSaving) { event.preventDefault(); this.statusTarget.textContent = "Save your selections before changing shelf settings." } }
  async save() {
    if (this.picksSaving) return false
    const picks = this.picks.map(({ id, type }) => ({ id, type }))
    const snapshot = JSON.stringify(picks)
    this.picksSaving = true
    this.statusTarget.textContent = "Saving…"
    try {
      const response = await fetch(this.urlValue, { method: "PATCH", headers: { "Content-Type": "application/json", "Accept": "application/json", "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || "" }, body: JSON.stringify({ picks, shelf_version: this.previewSignatureValue }) })
      const result = await response.json()
      if (!response.ok) throw new Error(result.error || "Save failed")
      this.previewSignatureValue = result.preview_signature
      this.element.querySelectorAll('input[name="shelf_version"]').forEach(input => { input.value = result.preview_signature })
      if (snapshot !== JSON.stringify(this.picks.map(({ id, type }) => ({ id, type })))) {
        this.dirty = true; this.statusTarget.textContent = "Your picks changed during saving. Save again before sharing."; return false
      }
      this.dirty = false; this.render(); this.statusTarget.textContent = "Shelf saved. Your public shelf is ready to share."; return true
    } catch (error) { this.statusTarget.textContent = error.message; return false }
    finally { this.picksSaving = false }
  }
  theme(event) {
    if (!this.ownerValue) return
    this.presentationDirty = true
    this.imageTheme = event.target.value
    try { localStorage.setItem("trove-shelf-theme", this.imageTheme) } catch { /* Presentation still works without storage. */ }
    this.applyTheme(); this.revealPreview(); this.schedulePreview()
  }
  customize(event) {
    if (!this.ownerValue) return
    this.presentationDirty = true
    const key = event.target.name
    if (!SHELF_STYLES[key]?.includes(event.target.value)) return
    this.imageStyle[key] = event.target.value
    try { localStorage.setItem("trove-shelf-style", JSON.stringify(this.imageStyle)) } catch { /* Optional storage. */ }
    this.applyTheme(); this.revealPreview(); this.schedulePreview()
  }
  applyTheme() {
    this.element.dataset.shelfTheme = this.imageTheme
    this.element.dataset.shelfTexture = this.imageStyle.texture
    this.element.dataset.shelfLayout = this.imageStyle.layout
    this.element.querySelectorAll('[name="layout"][type="radio"]').forEach(input => { input.checked = input.value === this.imageStyle.layout })
    for (const [key, value] of Object.entries(this.imageStyle)) { const input = this.element.querySelector(`select[name="${key}"]`); if (input) input.value = value }
    if (this.hasCompanionTarget) {
      const selected = this.imageStyle.companion === "auto" ? (this.imageTheme === "halloween" ? "bat" : this.imageTheme) : this.imageStyle.companion
      const source = this.assetsValue[selected]
      this.companionTarget.parentElement.hidden = !source
      if (source) this.companionTarget.src = source
      else this.companionTarget.removeAttribute("src")
    }
    this.element.querySelectorAll('input[name="shelf-theme"]').forEach(input => { input.checked = input.value === this.imageTheme })
    const paletteSelect = this.element.querySelector('select[name="shelf-theme"]'); if (paletteSelect) paletteSelect.value = this.imageTheme
    this.element.querySelectorAll('[data-shelf-link]').forEach(link => {
      const url = new URL(link.href); url.searchParams.set("theme", this.imageTheme); for (const [key, value] of Object.entries(this.imageStyle)) url.searchParams.set(key, value); link.href = url.href
    })
  }
  revealPreview() { const preview = this.canvasTarget.closest("details"); if (preview) preview.open = true }
  format(event) { this.imageFormat = event.target.value; this.revealPreview(); this.schedulePreview() }
  presentationSnapshot() { return JSON.stringify({ theme: this.imageTheme, ...this.imageStyle }) }
  async savePresentation() {
    if (!this.ownerValue) return true
    if (this.presentationSaving) { this.statusTarget.textContent = "Appearance is saving. Please wait, then retry sharing."; return false }
    if (!this.presentationDirty) { this.statusTarget.textContent = "Appearance saved. Visitors will see this presentation."; return true }
    const presentation = { theme: this.imageTheme, ...this.imageStyle }
    const snapshot = JSON.stringify(presentation)
    this.presentationSaving = true
    try {
      const response = await fetch(this.urlValue, { method: "PATCH", headers: { "Content-Type": "application/json", "Accept": "application/json", "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || "" }, body: JSON.stringify({ presentation, shelf_version: this.previewSignatureValue }) })
      if (!response.ok) throw new Error("Appearance save failed. Reload if this shelf changed in another window.")
      const result = await response.json?.()
      if (result?.preview_signature) {
        this.previewSignatureValue = result.preview_signature
        this.element.querySelectorAll('input[name="shelf_version"]').forEach(input => { input.value = result.preview_signature })
      }
      if (snapshot !== this.presentationSnapshot()) {
        this.presentationDirty = true
        this.statusTarget.textContent = "Your appearance changed during saving. Save again before sharing."
        return false
      }
      this.presentationDirty = false
      this.statusTarget.textContent = "Appearance saved. Visitors will see this presentation."
      return true
    } catch {
      this.statusTarget.textContent = "Could not save appearance. Your choices are preserved; retry before sharing."
      return false
    } finally { this.presentationSaving = false }
  }
  showSharing() { const panel = this.element.querySelector(".shelf-image-settings"); if (panel) panel.open = true }
  async nativeShare() {
    if (this.dirty) { this.statusTarget.textContent = "Save your changes before sharing."; return }
    if (!navigator.share) return this.copyLink()
    if (!(await this.savePresentation())) return
    try { await navigator.share({ title: this.headlineValue, url: this.publicUrlValue }); this.statusTarget.textContent = "Shelf shared." }
    catch (error) { if (error.name !== "AbortError") this.copyLink() }
  }
  async copyLink() {
    if (!(await this.savePresentation())) return
    if (this.dirty) { this.statusTarget.textContent = "Save your changes before sharing your public shelf."; return }
    const url = new URL(this.publicUrlValue || this.urlValue, window.location.origin); url.searchParams.set("theme", this.imageTheme); for (const [key, value] of Object.entries(this.imageStyle)) url.searchParams.set(key, value)
    try { await navigator.clipboard.writeText(url.href); this.statusTarget.textContent = "Shelf link copied, including your theme." }
    catch { this.statusTarget.textContent = `Copy this shelf link: ${url.href}` }
  }
  imageOptions() {
    return { picks: [...this.picks], shelves: this.shelvesValue,
      overview: this.overviewValue, headline: this.headlineValue, ...this.imageStyle, assets: this.assetsValue, theme: this.imageTheme, format: this.imageFormat,
      handle: this.handleValue, category: this.categoryValue, sharePath: this.urlValue, canonicalUrl: this.publicUrlValue }
  }
  async copyAltText() {
    if (!(await this.savePresentation())) return
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
    this.canvasTarget.setAttribute("aria-busy", "true")
    await renderShelfImage(canvas, options)
    if (version !== this.version || !this.element.isConnected) return
    this.canvasTarget.width = canvas.width; this.canvasTarget.height = canvas.height
    this.canvasTarget.getContext("2d").drawImage(canvas, 0, 0)
    this.canvasTarget.dataset.renderedLayout = options.layout
    this.canvasTarget.setAttribute("aria-busy", "false")
    return canvas
  }
  async publishPreview(event) {
    if (!this.ownerValue || this.publishing) return
    if (this.dirty) { this.statusTarget.textContent = "Save your shelf before publishing a share preview."; return }
    if (!(await this.savePresentation())) return
    const button = event.currentTarget
    this.publishing = true; button.disabled = true; button.setAttribute("aria-busy", "true")
    this.statusTarget.textContent = "Publishing your share preview…"
    try {
      const saved = await this.storePreview()
      this.statusTarget.textContent = saved ? "Share preview published. Your public shelf link is ready." : "Preview changed or could not be saved. Please try again."
    } catch { this.statusTarget.textContent = "Could not publish the preview. Your saved picks are safe. Please try again." }
    finally { this.publishing = false; button.disabled = false; button.removeAttribute("aria-busy") }
  }
  async storePreview() {
    const signature = this.previewSignatureValue, theme = this.imageTheme
    const style = JSON.stringify(this.imageStyle || {})
    const key = `${signature}:${theme}:${style}`
    const current = () => !this.dirty && !this.presentationDirty && this.element.isConnected &&
      signature === this.previewSignatureValue && theme === this.imageTheme && style === JSON.stringify(this.imageStyle || {})
    if (!current()) return false
    if (this.storedPreview === key) return true
    const canvas = document.createElement("canvas")
    await renderShelfImage(canvas, { ...this.imageOptions(), theme, format: "landscape" })
    if (!current()) return false
    const blob = await new Promise(resolve => canvas.toBlob(resolve, "image/png"))
    if (!blob || !current()) return false
    const body = new FormData()
    body.append("preview_image", blob, "shelf.png"); body.append("theme", theme)
    for (const [key, value] of Object.entries(JSON.parse(style))) body.append(key, value)
    body.append("preview_category", this.previewCategoryValue); body.append("preview_signature", signature)
    const response = await fetch(this.urlValue, { method: "PATCH", body,
      headers: { "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || "" } })
    if (response.ok) this.storedPreview = key
    return response.ok && current()
  }
  async download() {
    if (!(await this.savePresentation())) return
    if (this.dirty && !(await this.save())) return
    if (this.dirty || this.presentationDirty) { this.statusTarget.textContent = "Your choices changed during saving. Save again before downloading."; return }
    this.statusTarget.textContent = "Preparing your share image…"
    let canvas
    try { canvas = await this.preview() } catch { this.statusTarget.textContent = "Could not render this image. Your picks are safe; retry the download."; return }
    if (!canvas) { this.statusTarget.textContent = "Presentation changed. Download again to use the latest version."; return }
    const exportVersion = this.version
    canvas.toBlob(blob => {
      if (this.dirty || this.presentationDirty || exportVersion !== this.version) { this.statusTarget.textContent = "Your choices changed. Save and download again."; return }
      if (!blob) { this.statusTarget.textContent = "Image export failed. Please try again."; return }
      const url = URL.createObjectURL(blob), link = document.createElement("a")
      link.href = url; link.download = `trove-${this.handleValue}-${this.overviewValue ? "all-shelves" : this.categoryValue.replaceAll(" ", "-")}-${this.imageTheme}-${this.imageFormat}.png`; link.click()
      setTimeout(() => URL.revokeObjectURL(url), 1000); this.statusTarget.textContent = "PNG downloaded. Ready to share."
    }, "image/png")
  }
}
