import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["slots", "dialog", "query", "results", "status", "canvas"]
  static values = { picks: Array, url: String, search: String, handle: String, category: String }

  connect() {
    this.picks = this.picksValue; this.dirty = false; this.render()
    this.guard = event => { if (this.dirty) { event.preventDefault(); event.returnValue = "" } }
    this.visitGuard = event => { if (this.dirty && !window.confirm("Leave without saving your shelf?")) event.preventDefault() }
    window.addEventListener("beforeunload", this.guard)
    document.addEventListener("turbo:before-visit", this.visitGuard)
  }
  disconnect() { clearTimeout(this.timer); this.abort?.abort(); window.removeEventListener("beforeunload", this.guard); document.removeEventListener("turbo:before-visit", this.visitGuard) }
  button(text, action, label) {
    const button = document.createElement("button")
    button.type = "button"; button.textContent = text
    if (label) button.setAttribute("aria-label", label)
    button.addEventListener("click", action)
    return button
  }
  render() {
    const owner = this.slotsTarget.dataset.owner === "true"
    this.slotsTarget.replaceChildren()
    for (let index = 0; index < 5; index++) {
      const pick = this.picks[index], slot = document.createElement("article")
      slot.className = "shelf-slot"
      const cover = owner ? this.button(pick ? "Replace" : "+ Add favorite", () => this.open(index), `Choose favorite ${index + 1}`) : document.createElement("div")
      cover.className = "shelf-pick"
      if (pick?.cover) { const img = new Image(); img.src = pick.cover; img.alt = pick.title; cover.replaceChildren(img) }
      else if (pick) cover.textContent = pick.title
      else if (!owner) cover.textContent = "Not picked yet"
      const title = document.createElement("h3"); title.textContent = `${index + 1}. ${pick?.title || "Your next favorite"}`
      slot.append(cover, title)
      if (owner && pick) {
        const controls = document.createElement("div"); controls.className = "shelf-controls"
        const up = this.button("←", () => this.move(index, -1), `Move ${pick.title} earlier`); up.disabled = index === 0
        const down = this.button("→", () => this.move(index, 1), `Move ${pick.title} later`); down.disabled = index === this.picks.length - 1
        controls.append(up, down, this.button("Remove", () => { this.picks.splice(index, 1); this.changed() }))
        slot.append(controls)
      }
      this.slotsTarget.append(slot)
    }
    this.preview()
  }
  changed() { this.dirty = true; this.statusTarget.textContent = "Unsaved changes"; this.render() }
  move(index, direction) { [this.picks[index], this.picks[index + direction]] = [this.picks[index + direction], this.picks[index]]; this.changed() }
  open(index) { this.slot = Math.min(index, this.picks.length); this.dialogTarget.showModal(); this.queryTarget.value = ""; this.resultsTarget.textContent = "Type at least two characters to search."; this.queryTarget.focus() }
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
      this.dirty = false; this.statusTarget.textContent = "Shelf saved. Your public shelf is ready to share."
    } catch (error) { this.statusTarget.textContent = error.message }
  }
  async preview() {
    const version = this.version = (this.version || 0) + 1
    const picks = [...this.picks]
    const images = await Promise.all(picks.map(pick => new Promise(resolve => {
      if (!pick.cover) return resolve(null)
      const img = new Image(); img.crossOrigin = "anonymous"
      img.onload = () => resolve(img); img.onerror = () => resolve(null)
      img.src = `/media/covers/${encodeURIComponent(pick.type.replace(/([a-z])([A-Z])/g, "$1_$2").toLowerCase())}/${pick.id}`
    })))
    if (version !== this.version) return
    const ctx = this.canvasTarget.getContext("2d")
    ctx.fillStyle = "#f2ede4"; ctx.fillRect(0, 0, 1500, 1000)
    ctx.fillStyle = "#392d4c"; ctx.font = "bold 30px sans-serif"; ctx.fillText("TROVE / THE THINGS THAT STAY WITH YOU", 70, 90)
    ctx.font = "bold 66px sans-serif"; ctx.fillText(`My top five · ${this.categoryValue}`, 70, 190)
    for (let i = 0; i < 5; i++) {
      const x = 70 + i * 278, img = images[i]
      ctx.fillStyle = "#dcd2e5"; ctx.fillRect(x, 265, 250, 375)
      if (img) {
        const scale = Math.max(250 / img.width, 375 / img.height)
        ctx.save(); ctx.beginPath(); ctx.rect(x, 265, 250, 375); ctx.clip()
        ctx.drawImage(img, x + (250 - img.width * scale) / 2, 265 + (375 - img.height * scale) / 2, img.width * scale, img.height * scale); ctx.restore()
      }
      ctx.fillStyle = "#392d4c"; ctx.font = "bold 28px sans-serif"; ctx.fillText(`${i + 1}`, x, 690)
      ctx.font = "24px sans-serif"
      const words = (picks[i]?.title || "Not picked yet").split(/\s+/); let line = "", y = 730
      for (const word of words) {
        if (ctx.measureText(`${line} ${word}`).width > 250 && line) { ctx.fillText(line, x, y, 250); y += 32; line = "" }
        line += `${line ? " " : ""}${word}`
        if (y >= 826) { line += "…"; break }
      }
      ctx.fillText(line, x, y, 250)
    }
    ctx.font = "bold 38px sans-serif"; ctx.fillText(`trove.schweg.xyz/@${this.handleValue}`, 70, 940)
  }
  async download() {
    if (this.dirty) { this.statusTarget.textContent = "Save your changes before downloading so the image matches your public shelf."; return }
    await this.preview()
    this.canvasTarget.toBlob(blob => {
      if (!blob) { this.statusTarget.textContent = "Image export failed. Please try again."; return }
      const url = URL.createObjectURL(blob), link = document.createElement("a")
      link.href = url; link.download = `trove-${this.handleValue}-${this.categoryValue.replaceAll(" ", "-")}.png`; link.click()
      setTimeout(() => URL.revokeObjectURL(url), 1000); this.statusTarget.textContent = "PNG downloaded. Ready to share."
    }, "image/png")
  }
}
