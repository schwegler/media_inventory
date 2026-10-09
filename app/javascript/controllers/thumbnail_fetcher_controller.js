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
    "titleInput", "secondaryInput", "previewImg", "placeholder", "statusText", "optionsGrid", "thumbnailUrl",
    "director", "artist", "writer", "publisher", "releaseYear", "genre", "network", "venue", "promotion", "date",
    "season", "episode", "issueNumber", "apiId", "externalUrl", "manualFormSection", "developer", "platform",
    "searchStage", "detailsStage", "backBtn", "modalTitle", "selectedTitleDisplay", "author", "searchYear", "submitButton"
  ]
  static values = { mediaType: String }

  connect() {
    this.debouncedFetch = debounce(() => this.fetchThumbnails(), 300)
    this.currentQuery = ""

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
    this.debouncedFetch.cancel()
    this.fetchThumbnails()
  }

  search() {
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
    } else if (this.mediaTypeValue !== "comic" && this.hasSecondaryInputTarget && this.secondaryInputTarget.value.trim()) {
      query += " " + this.secondaryInputTarget.value.trim()
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
    
    if (this.hasSelectedTitleDisplayTarget) {
      const yearInfo = releaseYear ? ` (${releaseYear})` : ""
      this.selectedTitleDisplayTarget.textContent = `${title}${yearInfo}`
    }

    if (this.hasModalTitleTarget) {
      this.modalTitleTarget.textContent = "Log Details"
    }

    // Ensure focus is moved to an interactive element in the new stage
    if (this.hasBackBtnTarget) {
      setTimeout(() => this.backBtnTarget.focus(), 50)
    }
  }

  showManualForm() {
    const title = this.titleInputTarget.value.trim() || "New Item"
    const releaseYearVal = this.releaseYearTargets.length > 0 ? this.releaseYearTarget.value : null
    this.showDetailsStage(title, releaseYearVal)
  }

  goToSearch() {
    this.searchStageActive = this.hasSearchStageTarget
    if (this.searchStageActive) this.submitButtonTargets.forEach(button => { button.disabled = true })
    if (this.hasSearchStageTarget) this.searchStageTarget.classList.remove("hidden")
    if (this.hasDetailsStageTarget) this.detailsStageTarget.classList.add("hidden")
    if (this.hasBackBtnTarget) this.backBtnTarget.classList.add("hidden")

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
      setTimeout(() => this.titleInputTarget.focus(), 50)
    }
  }

  async fetchThumbnails() {
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
      let allResults = []

      this.searchAbortController?.abort()
      this.searchAbortController = new AbortController()
      const signal = this.searchAbortController.signal
      let response
      for (let attempt = 0; attempt < 40; attempt++) {
        response = await fetch(`/media/autocomplete?async=1&q=${encodeURIComponent(query)}&type=${encodeURIComponent(mediaType)}`, { signal })
        if (response.status !== 202) break
        await new Promise(resolve => setTimeout(resolve, 750))
        if (signal.aborted) return
      }
      if (response.status === 202) throw new Error("Search took too long")
      if (!response.ok) throw new Error(`Search failed: ${response.status}`)
      allResults = await response.json()
      if (this.currentQuery !== query) return

      // 3. Render Combined Options
      if (allResults.length === 0) {
        this.statusTextTarget.textContent = mediaType === "comic"
          ? "No matching series found. Try another start year, remove the year, or add manually."
          : "No covers found. Standard category icon will be used."
        return
      }

      this.statusTextTarget.textContent = mediaType === "comic"
        ? `${allResults.length} matching series. Select the run you want:`
        : "Select a result below:"
      this.optionsGridTarget.classList.toggle("comic-series-results", mediaType === "comic")

      allResults.forEach((option) => {
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
        image.src = option.thumbnail_url || "/favicon.svg"
        image.alt = option.title
        image.loading = "lazy"
        image.referrerPolicy = "no-referrer"
        image.addEventListener("error", () => { image.src = "/favicon.svg" }, { once: true })
        const badge = document.createElement("span")
        badge.className = `option-badge ${badgeClass}`
        badge.textContent = option.source || badgeText
        const label = document.createElement("div")
        label.className = "option-label"
        if (mediaType === "comic") {
          const seriesTitle = document.createElement("strong")
          seriesTitle.textContent = option.title.replace(/\s*\(\d{4}\)$/, "")
          const year = document.createElement("span")
          year.className = "option-series-year"
          year.textContent = option.release_year ? `Started ${option.release_year}` : "Start year unknown"
          const details = document.createElement("span")
          details.textContent = [option.publisher, option.issue_count ? `${option.issue_count} issues` : null, subtitle].filter(Boolean).join(" · ")
          label.append(seriesTitle, year, details)
        } else {
          label.textContent = tooltipText
        }
        wrapper.append(image, badge)
        imgBtn.append(wrapper, label)

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
        this.selectOption(allResults[idx], false)
      }

    } catch (err) {
      if (err.name === "AbortError") return
      console.error("Error fetching thumbnails:", err)
      this.statusTextTarget.textContent = "Error loading covers."
    } finally {
      if (this.currentQuery === query) this.statusTextTarget.classList.remove("search-pending")
    }
  }

  selectOption(option, isManualClick = false) {
    // 1. Update cover art URL and previews
    this.thumbnailUrlTarget.value = option.cover_source_url || option.thumbnail_url || ""
    this.previewImgTarget.src = option.thumbnail_url || "/favicon.svg"
    this.previewImgTarget.style.display = "block"
    this.placeholderTarget.style.display = "none"

    if (isManualClick) {
      // 2. Auto-populate text fields only on direct selection
      if (this.hasTitleInputTarget) {
        let finalTitle = option.title
        if (option.release_year && !finalTitle.includes(`(${option.release_year})`)) {
          finalTitle = `${finalTitle} (${option.release_year})`
        }
        this.titleInputTarget.value = finalTitle
      }

      // 3. Auto-populate targets dynamically
      if (this.hasDirectorTarget) this.directorTarget.value = option.director || ""
      if (this.hasArtistTarget) this.artistTarget.value = option.artist || ""
      if (this.hasWriterTarget) this.writerTarget.value = option.writer || ""
      if (this.hasAuthorTarget) this.authorTarget.value = option.author || ""
      if (this.hasPublisherTarget) this.publisherTarget.value = option.publisher || ""
      if (this.releaseYearTargets.length > 0) this.releaseYearTarget.value = option.release_year || ""
      if (this.hasGenreTarget) this.genreTarget.value = option.genre || ""
      if (this.hasNetworkTarget) this.networkTarget.value = option.network || ""
      if (this.hasDeveloperTarget) this.developerTarget.value = option.developer || ""
      if (this.hasPlatformTarget) this.platformTarget.value = option.platform || ""
      if (this.hasSeasonTarget) this.seasonTarget.value = option.season || ""
      if (this.hasEpisodeTarget) this.episodeTarget.value = option.episode || ""
      if (this.hasIssueNumberTarget) this.issueNumberTarget.value = option.issue_number || ""
      if (this.hasApiIdTarget) this.apiIdTarget.value = option.api_id || ""
      if (this.hasExternalUrlTarget) this.externalUrlTarget.value = option.external_url || ""

      // 4. Transition to details view!
      this.showDetailsStage(option.title, option.release_year)
    }
  }
}
