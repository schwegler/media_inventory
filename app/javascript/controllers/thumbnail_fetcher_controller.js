import { Controller } from "@hotwired/stimulus"

// Debounce helper
function debounce(func, wait) {
  let timeout
  const executedFunction = function (...args) {
    const later = () => {
      clearTimeout(timeout)
      func(...args)
    }
    clearTimeout(timeout)
    timeout = setTimeout(later, wait)
  }
  executedFunction.cancel = () => clearTimeout(timeout)
  return executedFunction
}

// Connects to data-controller="thumbnail-fetcher"
export default class extends Controller {
  static targets = [
    "titleInput", "previewImg", "placeholder", "statusText", "optionsGrid", "thumbnailUrl",
    "director", "artist", "writer", "actors", "publisher", "releaseYear", "genre", "network", "venue", "promotion", "date",
    "season", "episode", "issueNumber", "apiId", "catalogSelection", "externalUrl", "manualFormSection", "developer", "platform",
    "searchStage", "detailsStage", "backBtn", "modalTitle", "selectedTitleDisplay", "gameType", "author", "searchYear", "submitButton"
  ]
  static values = { mediaType: String }

  connect() {
    this.debouncedFetch = debounce(() => this.fetchThumbnails(), 300)
    this.currentQuery = ""
    this.searchClient = crypto.randomUUID()

    // Pre-populate preview if thumbnail URL already has a value
    if (this.thumbnailUrlTarget.value) {
      this.previewImgTarget.src = this.thumbnailUrlTarget.value
      this.previewImgTarget.style.display = "block"
      this.placeholderTarget.style.display = "none"
    }

    const hasErrors = this.element.querySelector("#error_explanation") !== null
    if (hasErrors) {
      const currentTitle = this.titleInputTarget.value || "Details"
      const releaseYearVal = this.releaseYearTargets.length > 0 ? this.releaseYearTarget.value : null
      this.showDetailsStage(currentTitle, releaseYearVal)
    } else {
      this.goToSearch()
    }

    this.formElement = this.element.querySelector("form")
    this.searchKeydownHandler = (event) => this.handleSearchKeydown(event)
    this.searchSubmitHandler = (event) => this.handleSearchSubmit(event)
    this.formElement?.addEventListener("keydown", this.searchKeydownHandler)
    this.formElement?.addEventListener("submit", this.searchSubmitHandler, true)
    this.element.dataset.connected = "true"
  }

  disconnect() {
    this.debouncedFetch.cancel()
    this.searchAbortController?.abort()
    this.formElement?.removeEventListener("keydown", this.searchKeydownHandler)
    this.formElement?.removeEventListener("submit", this.searchSubmitHandler, true)
  }

  handleSearchKeydown(event) {
    if (!this.searchStageActive || event.key !== "Enter" || event.isComposing) return
    if (!this.searchStageTarget.contains(event.target) || !event.target.matches("input")) return

    event.preventDefault()
    if (!event.repeat) this.searchNow()
  }

  handleSearchSubmit(event) {
    if (!this.searchStageActive) return

    event.preventDefault()
    event.stopImmediatePropagation()
    this.searchNow()
  }

  searchNow() {
    if (!this.searchStageActive) return
    this.debouncedFetch.cancel()
    this.fetchThumbnails()
  }

  search() {
    if (!this.searchStageActive) return
    this.clearGameSelection()
    this.searchAbortController?.abort()
    this.currentQuery = this.searchQuery()
    this.statusTextTarget.textContent = this.currentQuery ? "Searching…" : "Type title to fetch covers..."
    this.statusTextTarget.classList.toggle("search-pending", Boolean(this.currentQuery))
    this.debouncedFetch()
  }

  searchQuery() {
    let query = this.titleInputTarget.value.trim()
    if (this.mediaTypeValue === "comic" && this.hasSearchYearTarget && this.searchYearTarget.value.trim()) {
      query = query.replace(/\s+\(?\d{4}\)?$/, "")
      query += ` (${this.searchYearTarget.value.trim()})`
    }
    return query
  }

  showDetailsStage(title, releaseYear) {
    this.searchStageActive = false
    this.submitButtonTargets.forEach(button => { button.disabled = false })
    this.debouncedFetch.cancel()
    this.searchAbortController?.abort()
    if (this.hasSearchStageTarget) this.searchStageTarget.classList.add("hidden")
    if (this.hasDetailsStageTarget) this.detailsStageTarget.classList.remove("hidden")
    if (this.hasBackBtnTarget) this.backBtnTarget.classList.remove("hidden")
    if (this.hasManualFormSectionTarget) this.manualFormSectionTarget.style.display = "block"
    
    if (this.hasSelectedTitleDisplayTarget) {
      const yearInfo = releaseYear ? ` (${releaseYear})` : ""
      this.selectedTitleDisplayTarget.textContent = `${title}${yearInfo}`
    }

    if (this.hasModalTitleTarget) {
      this.modalTitleTarget.textContent = "Log Details"
    }

    // Ensure focus is moved to an interactive element in the new stage
    if (this.hasBackBtnTarget) {
      const editingDetails = this.hasDetailsStageTarget && this.detailsStageTarget.contains(document.activeElement)
      if (!editingDetails) this.backBtnTarget.focus()
    }
  }

  showManualForm() {
    this.clearGameSelection()
    const title = this.titleInputTarget.value.trim() || "New Item"
    const releaseYearVal = this.releaseYearTargets.length > 0 ? this.releaseYearTarget.value : null
    this.showDetailsStage(title, releaseYearVal)
  }

  goToSearch() {
    this.searchStageActive = this.hasSearchStageTarget || (this.hasManualFormSectionTarget && this.manualFormSectionTarget.style.display === "none")
    if (this.hasSearchStageTarget) this.submitButtonTargets.forEach(button => { button.disabled = true })
    if (this.hasSearchStageTarget) this.searchStageTarget.classList.remove("hidden")
    if (this.hasDetailsStageTarget) this.detailsStageTarget.classList.add("hidden")
    if (this.hasBackBtnTarget) this.backBtnTarget.classList.add("hidden")
    if (this.hasManualFormSectionTarget) this.manualFormSectionTarget.style.display = "none"

    if (this.hasModalTitleTarget) {
      const mediaNames = {
        movie: "Log Movie",
        album: "Log Album",
        comic: "Log Comic",
        tv_show: "Log TV Show",
        video_game: "Log Video Game",
        book: "Log Book"
      }
      this.modalTitleTarget.textContent = mediaNames[this.mediaTypeValue] || "Log Media"
    }

    // Focus search input when returning to search stage
    if (this.hasTitleInputTarget) {
      this.titleInputTarget.focus()
    }
  }

  async fetchThumbnails() {
    if (!this.searchStageActive) return
    this.statusTextTarget.classList.remove("search-pending")
    const title = this.titleInputTarget.value.trim()
    if (!title) {
      this.optionsGridTarget.innerHTML = ""
      this.statusTextTarget.textContent = "Type title to fetch covers..."
      this.currentQuery = ""
      return
    }

    const query = this.searchQuery()
    this.currentQuery = query
    this.statusTextTarget.textContent = "Searching local database and web..."
    this.optionsGridTarget.innerHTML = ""
    this.statusTextTarget.classList.add("search-pending")

    try {
      const mediaType = this.mediaTypeValue
      this.searchAbortController?.abort()
      this.searchAbortController = new AbortController()
      const signal = this.searchAbortController.signal
      let previousResults
      for (let attempt = 0; attempt < 80; attempt++) {
        const response = await fetch(`/media/autocomplete?async=1&q=${encodeURIComponent(query)}&type=${encodeURIComponent(mediaType)}&search_client=${this.searchClient}`, { signal })
        if (!response.ok) throw new Error(`Search failed: ${response.status}`)
        const results = await response.json()
        if (signal.aborted || !this.searchStageActive || this.currentQuery !== query) return
        const pending = response.status === 202
        const serialized = JSON.stringify(results)
        if (serialized !== previousResults || !pending) {
          this.renderResults(results, mediaType, pending)
          previousResults = serialized
        }
        if (!pending) return
        await new Promise(resolve => setTimeout(resolve, 400))
        if (signal.aborted || !this.searchStageActive) return
      }
      this.statusTextTarget.textContent = "Search is taking longer than expected. Select a result, try again, or add manually."

    } catch (err) {
      if (err.name === "AbortError") return
      console.error("Error fetching thumbnails:", err)
      this.statusTextTarget.textContent = "Error loading covers."
    } finally {
      if (this.currentQuery === query) this.statusTextTarget.classList.remove("search-pending")
    }
  }

  renderResults(results, mediaType, pending = false) {
    if (!this.searchStageActive) return
    this.optionsGridTarget.innerHTML = ""
    if (results.length === 0) {
      if (pending) {
        this.statusTextTarget.textContent = "Searching web sources…"
        return
      }
      this.statusTextTarget.textContent = mediaType === "comic"
        ? "No matching series found. Try another start year, remove the year, or add manually."
        : "No matches found. Try another title or add manually."
      return
    }

    this.statusTextTarget.textContent = pending ? "Select a result, or wait for more web matches…" : mediaType === "comic"
      ? `${results.length} matching series. Select the run you want:`
      : "Select a result below:"
    this.optionsGridTarget.dataset.mediaType = mediaType
    this.optionsGridTarget.classList.toggle("comic-series-results", mediaType === "comic")
    this.optionsGridTarget.classList.toggle("game-search-results", mediaType === "video_game")
    this.optionsGridTarget.classList.toggle("album-search-results", mediaType === "album")

    results.forEach((option) => {
      const imgBtn = document.createElement("div")
      imgBtn.className = "thumbnail-option-card"
      imgBtn.setAttribute("tabindex", "0")
      imgBtn.setAttribute("role", "button")

      const badgeClass = option.is_local ? "local" : "web"
      const badgeText = option.is_local ? "Local" : "Web"

      let subtitle = ""
      if (mediaType === "movie") subtitle = option.director || ""
      else if (mediaType === "album") subtitle = option.artist || ""
      else if (mediaType === "comic") subtitle = option.writer || ""
      else if (mediaType === "tv_show") subtitle = option.network || ""
      else if (mediaType === "video_game") subtitle = option.developer || ""
      else if (mediaType === "book") subtitle = option.author || ""

      const yearInfo = option.release_year ? ` (${option.release_year})` : ""
      const tooltipText = `${option.title}${yearInfo} ${subtitle ? `- ${subtitle}` : ""}`
      imgBtn.setAttribute("aria-label", `Select ${option.title}${yearInfo}`)
      imgBtn.title = tooltipText
      const wrapper = document.createElement("div")
      wrapper.className = "thumbnail-option-img-wrap"
      const image = document.createElement("img")
      image.src = option.thumbnail_url || (mediaType === "video_game" ? "/missing-game-cover.svg" : "/favicon.svg")
      image.alt = option.title
      image.loading = "lazy"
      image.referrerPolicy = "no-referrer"
      image.addEventListener("error", () => { image.src = mediaType === "video_game" ? "/missing-game-cover.svg" : "/favicon.svg" }, { once: true })
      const badge = document.createElement("span")
      badge.className = `option-badge ${badgeClass}`
      badge.textContent = option.source || badgeText
      const label = document.createElement("div")
      label.className = "option-label"
      if (mediaType === "video_game") {
        const title = document.createElement("strong")
        title.className = "option-title"
        title.textContent = option.title
        const details = document.createElement("span")
        details.className = "option-details"
        details.textContent = [option.release_year || "Year unknown", option.platform, option.game_type || "Type unknown"].filter(Boolean).join(" · ")
        const coverStatus = document.createElement("span")
        coverStatus.className = "option-cover-status"
        coverStatus.textContent = option.artwork_status === "missing" ? "Cover unavailable" : option.artwork_source ? `Art: ${option.artwork_source}` : ""
        label.append(title, details, coverStatus)
      } else if (mediaType === "comic") {
        const seriesTitle = document.createElement("strong")
        seriesTitle.className = "option-title"
        seriesTitle.textContent = option.title.replace(/\s*\(\d{4}\)$/, "")
        const year = document.createElement("span")
        year.className = "option-series-year"
        year.textContent = option.release_year ? `Started ${option.release_year}` : "Start year unknown"
        const details = document.createElement("span")
        details.className = "option-details"
        details.textContent = [option.publisher, option.issue_count ? `${option.issue_count} issues` : null, subtitle].filter(Boolean).join(" · ")
        label.append(seriesTitle, year, details)
      } else {
        const title = document.createElement("strong")
        title.className = "option-title"
        title.textContent = option.title
        const details = document.createElement("span")
        details.className = "option-details"
        const metaParts = []
        if (option.release_year) metaParts.push(option.release_year)
        if (subtitle) metaParts.push(subtitle)
        details.textContent = metaParts.join(" · ")
        label.append(title, details)
      }
      const selectCue = document.createElement("span")
      selectCue.className = "option-select-cue"
      selectCue.setAttribute("aria-hidden", "true")
      selectCue.textContent = "Select"
      wrapper.append(image, badge)
      imgBtn.append(wrapper, label, selectCue)

      imgBtn.addEventListener("click", (e) => {
        this.optionsGridTarget.querySelectorAll(".thumbnail-option-card").forEach(card => card.classList.remove("selected"))
        imgBtn.classList.add("selected")

        // User clicked explicitly, so populate all text fields and transition to details view!
        this.selectOption(option, true)
      })

      imgBtn.addEventListener("keydown", (e) => {
        if (e.key === "Enter" || e.key === " ") {
          e.preventDefault()
          this.optionsGridTarget.querySelectorAll(".thumbnail-option-card").forEach(card => card.classList.remove("selected"))
          imgBtn.classList.add("selected")
          this.selectOption(option, true)
        }
      })

      this.optionsGridTarget.appendChild(imgBtn)
    })

    // Auto-select first cover invisibly (only update cover preview, NOT text inputs!)
    const firstCard = this.optionsGridTarget.querySelector(".thumbnail-option-card")
    if (firstCard) {
      this.optionsGridTarget.querySelectorAll(".thumbnail-option-card").forEach(card => card.classList.remove("selected"))
      firstCard.classList.add("selected")
      const idx = Array.from(this.optionsGridTarget.children).indexOf(firstCard)
      this.selectOption(results[idx], false)
    }

  }

  clearGameSelection() {
    if (this.mediaTypeValue !== "video_game") return
    if (this.hasCatalogSelectionTarget) this.catalogSelectionTarget.value = ""
    if (this.hasApiIdTarget) this.apiIdTarget.value = ""
    if (this.hasExternalUrlTarget) this.externalUrlTarget.value = ""
    for (const name of ["developer", "publisher", "platform", "releaseYear", "gameType", "thumbnailUrl"]) {
      const target = this.targets.find(name)
      if (target) target.value = name === "gameType" ? "unknown" : ""
    }
    if (this.hasPreviewImgTarget) this.previewImgTarget.style.display = "none"
    if (this.hasPlaceholderTarget) this.placeholderTarget.style.display = "block"
  }

  selectOption(option, isManualClick = false) {
    if (!isManualClick && !this.searchStageActive) return

    // 1. Update cover art URL and previews
    this.thumbnailUrlTarget.value = option.cover_source_url || option.thumbnail_url || ""
    this.previewImgTarget.src = option.thumbnail_url || (this.mediaTypeValue === "video_game" ? "/missing-game-cover.svg" : "/favicon.svg")
    this.previewImgTarget.style.display = "block"
    this.placeholderTarget.style.display = "none"

    if (isManualClick) {
      // 2. Auto-populate text fields only on direct selection
      if (this.hasTitleInputTarget) {
        let finalTitle = option.title
        if (this.mediaTypeValue !== "video_game" && option.release_year && !finalTitle.includes(`(${option.release_year})`)) {
          finalTitle = `${finalTitle} (${option.release_year})`
        }
        this.titleInputTarget.value = finalTitle
      }

      // 3. Auto-populate targets dynamically
      if (this.hasDirectorTarget) this.directorTarget.value = option.director || ""
      if (this.hasArtistTarget) this.artistTarget.value = option.artist || ""
      if (this.hasWriterTarget) this.writerTarget.value = option.writer || ""
      if (this.hasActorsTarget) this.actorsTarget.value = option.actors || ""
      if (this.hasAuthorTarget) this.authorTarget.value = option.author || ""
      if (this.hasPublisherTarget) this.publisherTarget.value = option.publisher || ""
      if (this.releaseYearTargets.length > 0) this.releaseYearTarget.value = option.release_year || ""
      if (this.hasGenreTarget) this.genreTarget.value = option.genre || ""
      if (this.hasNetworkTarget) this.networkTarget.value = option.network || ""
      if (this.hasGameTypeTarget) this.gameTypeTarget.value = option.game_type || "unknown"
      if (this.hasDeveloperTarget) this.developerTarget.value = option.developer || ""
      if (this.hasPlatformTarget) this.platformTarget.value = option.platform || ""
      if (this.hasSeasonTarget) this.seasonTarget.value = option.season || ""
      if (this.hasEpisodeTarget) this.episodeTarget.value = option.episode || ""
      if (this.hasIssueNumberTarget) this.issueNumberTarget.value = option.issue_number || ""
      if (this.hasApiIdTarget) this.apiIdTarget.value = option.api_id || ""
      if (this.hasCatalogSelectionTarget) this.catalogSelectionTarget.value = option.catalog_selection || ""
      if (this.hasExternalUrlTarget) this.externalUrlTarget.value = option.external_url || ""

      // 4. Transition to details view!
      this.showDetailsStage(option.title, option.release_year)
    }
  }
}
