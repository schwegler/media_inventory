import { Controller } from "@hotwired/stimulus"

// One selected media type, one cached async search; never fan out across types.
export default class extends Controller {
  static values = { query: String, type: String, signedIn: Boolean, selectionUrl: String }
  static targets = ["status", "results", "retry"]

  connect() {
    this.client = crypto.randomUUID()
    this.search()
  }

  disconnect() { this.abort?.abort() }

  async search() {
    this.abort?.abort()
    this.abort = new AbortController()
    const { signal } = this.abort
    this.retryTarget.hidden = true
    this.statusTarget.textContent = "Searching supported catalogs…"
    let previous
    try {
      for (let attempt = 0; attempt < 80; attempt++) {
        const params = new URLSearchParams({ q: this.queryValue, type: this.typeValue, async: "1", discovery: "1", search_client: this.client })
        const response = await fetch(`/media/autocomplete?${params}`, { signal, headers: { Accept: "application/json" } })
        if (!response.ok) throw new Error("Catalog search unavailable")
        const data = await response.json()
        if (signal.aborted) return
        const results = data.results.filter(result => !result.is_local || result.source)
        const serialized = JSON.stringify(results)
        if (previous !== serialized) this.renderResults(results)
        previous = serialized
        const pending = response.status === 202
        const unavailable = data.sources.some(source => source.state === "unavailable")
        const noSources = !data.sources.length
        this.statusTarget.textContent = pending ? "Searching catalogs. You can choose a result while more arrive…" : unavailable
          ? "Some catalogs could not be searched. Available matches are shown; try again or refine your search."
          : noSources ? "Catalog availability could not be confirmed. Refine your search or retry; these are only selected matches."
          : results.length ? "Selected provider matches, not a complete catalog. Refine your search to find more."
          : "No additional titles to import from the sources searched. Matches already in Trove appear above. Try an album or other title, or refine the artist’s name. Coverage varies by source."
        if (!pending) { this.retryTarget.hidden = !(unavailable || noSources); return }
        await new Promise(resolve => setTimeout(resolve, 400))
      }
      throw new Error("Search timed out")
    } catch (error) {
      if (error.name === "AbortError") return
      this.statusTarget.textContent = "Catalog search is unavailable or taking too long. Your Trove results are still available. Retry or refine your search."
      this.retryTarget.hidden = false
    }
  }

  renderResults(results) {
    const focused = this.resultsTarget.contains(document.activeElement) ? document.activeElement.dataset.selectionKey : null
    const fragment = document.createDocumentFragment()
    for (const result of results) {
      const card = document.createElement("article")
      card.className = "discovery-result"
      const heading = document.createElement("h3")
      heading.textContent = result.title
      const detail = document.createElement("p")
      detail.textContent = [result.artist || result.author || result.director || result.writer || result.developer || result.network, result.release_year].filter(Boolean).join(" · ")
      const badge = document.createElement("p")
      badge.className = "discovery-provenance"
      badge.textContent = result.is_local ? `In Trove${result.in_library ? " · In your library" : ""}` : `Available to import · ${result.source || "Supported catalog"}`
      if (result.is_local && result.catalog_id) {
        const link = document.createElement("a")
        const paths = { album: "albums", movie: "movies", tv_show: "tv_shows", book: "books", comic: "comics", video_game: "video_games" }
        link.href = `/${paths[this.typeValue]}/${encodeURIComponent(result.catalog_id)}`
        link.textContent = result.in_library ? "View in your library" : "View title in Trove"
        link.className = "sleek-btn sleek-btn-secondary"
        link.dataset.selectionKey = result.api_id || result.external_url || result.title
        card.append(badge, heading, detail, link)
        fragment.append(card)
        continue
      }
      const form = document.createElement("form")
      form.method = "post"
      form.action = this.selectionUrlValue
      const fields = { authenticity_token: document.querySelector('meta[name="csrf-token"]')?.content || "", selection: result.import_selection, type: this.typeValue, q: this.queryValue }
      for (const [name, value] of Object.entries(fields)) {
        const input = document.createElement("input")
        input.type = "hidden"; input.name = name; input.value = value || ""
        form.append(input)
      }
      const button = document.createElement("button")
      button.type = "submit"
      button.className = "sleek-btn sleek-btn-secondary"
      button.dataset.selectionKey = result.api_id || result.external_url || result.title
      button.textContent = this.signedInValue ? "Review import and add" : "Sign in to import and add"
      button.setAttribute("aria-label", `${button.textContent}: ${result.title}`)
      form.append(button)
      card.append(badge, heading, detail, form)
      fragment.append(card)
    }
    this.resultsTarget.replaceChildren(fragment)
    if (focused) Array.from(this.resultsTarget.querySelectorAll("[data-selection-key]")).find(button => button.dataset.selectionKey === focused)?.focus()
  }
}
