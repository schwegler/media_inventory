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
    "searchStage", "detailsStage", "backBtn", "modalTitle", "selectedTitleDisplay", "author"
  ]
  static values = { mediaType: String }

  connect() {
    this.debouncedFetch = debounce(() => this.fetchThumbnails(), 600)
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
    this.element.dataset.connected = "true"
  }

  disconnect() {
    this.debouncedFetch.cancel()
    this.searchAbortController?.abort()
  }

  search() {
    this.searchAbortController?.abort()
    this.currentQuery = this.titleInputTarget.value.trim()
    this.debouncedFetch()
  }

  showDetailsStage(title, releaseYear) {
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
    const title = this.titleInputTarget.value.trim()
    if (!title) {
      this.optionsGridTarget.innerHTML = ""
      this.statusTextTarget.textContent = "Type title to fetch covers..."
      this.currentQuery = ""
      return
    }

    this.currentQuery = title
    this.statusTextTarget.textContent = "Searching local database and web..."
    this.optionsGridTarget.innerHTML = ""

    let query = title
    if (this.hasSecondaryInputTarget && this.secondaryInputTarget.value.trim()) {
      query += " " + this.secondaryInputTarget.value.trim()
    }

    try {
      const mediaType = this.mediaTypeValue
      let allResults = []

      this.searchAbortController?.abort()
      this.searchAbortController = new AbortController()
      const response = await fetch(`/media/autocomplete?q=${encodeURIComponent(query)}&type=${encodeURIComponent(mediaType)}`, {
        signal: this.searchAbortController.signal
      })
      if (!response.ok) throw new Error(`Search failed: ${response.status}`)
      allResults = await response.json()
      if (this.currentQuery !== title) return

      // 3. Render Combined Options
      if (allResults.length === 0) {
        this.statusTextTarget.textContent = "No covers found. Standard category icon will be used."
        return
      }

      this.statusTextTarget.textContent = "Select a result below:"

      allResults.forEach((option) => {
        const imgBtn = document.createElement("div")
        imgBtn.className = "thumbnail-option-card"
        imgBtn.setAttribute("tabindex", "0")
        imgBtn.setAttribute("role", "button")
        imgBtn.setAttribute("aria-label", `Select ${option.title}`)
        
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
        label.textContent = tooltipText
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
