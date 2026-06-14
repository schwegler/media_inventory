import { Controller } from "@hotwired/stimulus"

// Debounce helper
function debounce(func, wait) {
  let timeout
  return function executedFunction(...args) {
    const later = () => {
      clearTimeout(timeout)
      func(...args)
    }
    clearTimeout(timeout)
    timeout = setTimeout(later, wait)
  }
}

// Connects to data-controller="thumbnail-fetcher"
export default class extends Controller {
  static targets = [
    "titleInput", "secondaryInput", "previewImg", "placeholder", "statusText", "optionsGrid", "thumbnailUrl",
    "director", "artist", "writer", "publisher", "releaseYear", "genre", "network", "venue", "promotion", "date",
    "season", "episode", "issueNumber", "apiId", "externalUrl", "manualFormSection", "developer", "platform"
  ]
  static values = { mediaType: String }

  connect() {
    this.debouncedFetch = debounce(() => this.fetchThumbnails(), 600)

    // Pre-populate preview if thumbnail URL already has a value
    if (this.thumbnailUrlTarget.value) {
      this.previewImgTarget.src = this.thumbnailUrlTarget.value
      this.previewImgTarget.style.display = "block"
      this.placeholderTarget.style.display = "none"
    }
  }

  search() {
    this.debouncedFetch()
  }

  showManualForm() {
    if (this.hasManualFormSectionTarget) {
      this.manualFormSectionTarget.style.display = "block"
    }
  }

  async fetchThumbnails() {
    const title = this.titleInputTarget.value.trim()
    if (!title) {
      this.optionsGridTarget.innerHTML = ""
      this.statusTextTarget.textContent = "Type title to fetch covers..."
      return
    }

    this.statusTextTarget.textContent = "Searching local database and web..."
    this.optionsGridTarget.innerHTML = ""

    let query = title
    if (this.hasSecondaryInputTarget && this.secondaryInputTarget.value.trim()) {
      query += " " + this.secondaryInputTarget.value.trim()
    }

    try {
      const mediaType = this.mediaTypeValue
      let allResults = []

      // 1. Fetch Local Matches First
      try {
        const localResponse = await fetch(`/media/autocomplete?q=${encodeURIComponent(title)}&type=${mediaType}`)
        if (localResponse.ok) {
          const localData = await localResponse.json()
          allResults = allResults.concat(localData)
        }
      } catch (localErr) {
        console.error("Local autocomplete failed:", localErr)
      }

      // 2. Fetch Web Matches
      let webResults = await this.queryWebAPI(query, mediaType)
      
      // If we got 0 web results and the query has more than 3 words, try retrying with just the first 3 words
      const words = query.split(/\s+/)
      if (webResults.length === 0 && words.length > 3) {
        const simplifiedQuery = words.slice(0, 3).join(" ")
        webResults = await this.queryWebAPI(simplifiedQuery, mediaType)
      }
      // If still 0, try the first 2 words
      if (webResults.length === 0 && words.length > 2) {
        const simplifiedQuery2 = words.slice(0, 2).join(" ")
        webResults = await this.queryWebAPI(simplifiedQuery2, mediaType)
      }

      allResults = allResults.concat(webResults)

      // 3. Render Combined Options
      if (allResults.length === 0) {
        this.statusTextTarget.textContent = "No covers found. Standard category icon will be used."
        return
      }

      this.statusTextTarget.textContent = "Select a cover or click a button below to save instantly:"

      allResults.forEach((option) => {
        const imgBtn = document.createElement("div")
        imgBtn.className = "thumbnail-option-card"
        
        // Add badges for Local vs Web
        const badgeClass = option.is_local ? "local" : "web"
        const badgeText = option.is_local ? "Local" : "Web"
        
        // Build subtitle/meta details for tooltip
        let subtitle = ""
        if (mediaType === "movie") subtitle = option.director || ""
        else if (mediaType === "album") subtitle = option.artist || ""
        else if (mediaType === "comic") subtitle = option.writer || ""
        else if (mediaType === "tv_show") subtitle = option.network || ""
        else if (mediaType === "video_game") subtitle = option.developer || ""
        
        const yearInfo = option.release_year ? ` (${option.release_year})` : ""
        const tooltipText = `${option.title}${yearInfo} ${subtitle ? `- ${subtitle}` : ""}`
        const fallbackUrl = mediaType === "video_game"
          ? 'https://images.unsplash.com/photo-1550745165-9bc0b252726f?auto=format&fit=crop&w=400&h=600&q=80'
          : 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?auto=format&fit=crop&w=400&h=600&q=80';

        imgBtn.innerHTML = `
          <div class="thumbnail-option-img-wrap">
            <img src="${option.thumbnail_url}" alt="${option.title}" onerror="this.onerror=null; this.src='${fallbackUrl}';">
            <span class="option-badge ${badgeClass}">${badgeText}</span>
            <div class="option-tooltip">${tooltipText}</div>
          </div>
          <div class="thumbnail-option-actions">
            <button type="button" class="option-action-btn add-collection-btn">+ Collection</button>
            <button type="button" class="option-action-btn add-watchlist-btn">+ Watchlist</button>
          </div>
        `

        imgBtn.addEventListener("click", (e) => {
          this.optionsGridTarget.querySelectorAll(".thumbnail-option-card").forEach(card => card.classList.remove("selected"))
          imgBtn.classList.add("selected")

          this.selectOption(option)

          const isCollectedInput = this.element.querySelector('input[name*="[is_collected]"]')
          const inWatchlistInput = this.element.querySelector('input[name*="[in_watchlist]"]')
          const form = this.element.querySelector("form")

          if (e.target.classList.contains("add-collection-btn")) {
            if (isCollectedInput) isCollectedInput.checked = true
            if (inWatchlistInput) inWatchlistInput.checked = false
            if (form) form.requestSubmit()
          } else if (e.target.classList.contains("add-watchlist-btn")) {
            if (isCollectedInput) isCollectedInput.checked = false
            if (inWatchlistInput) inWatchlistInput.checked = true
            const consumedInput = this.element.querySelector('input[name*="[consumed]"]')
            if (consumedInput) consumedInput.checked = false
            if (form) form.requestSubmit()
          }
        })

        this.optionsGridTarget.appendChild(imgBtn)
      })

      // Auto-select first cover if user hasn't selected one
      const firstCard = this.optionsGridTarget.querySelector(".thumbnail-option-card")
      if (firstCard) {
        this.optionsGridTarget.querySelectorAll(".thumbnail-option-card").forEach(card => card.classList.remove("selected"))
        firstCard.classList.add("selected")
        const idx = Array.from(this.optionsGridTarget.children).indexOf(firstCard)
        this.selectOption(allResults[idx])
      }

    } catch (err) {
      console.error("Error fetching thumbnails:", err)
      this.statusTextTarget.textContent = "Error loading covers."
    }
  }

  async queryWebAPI(query, mediaType) {
    try {
      if (mediaType === "movie") {
        const url = `https://itunes.apple.com/search?term=${encodeURIComponent(query)}&limit=15&country=US`
        const response = await fetch(url)
        const data = await response.json()
        return (data.results || [])
          .filter(r => r.kind === "feature-movie")
          .slice(0, 5)
          .map(r => ({
            title: r.trackName,
            director: r.artistName,
            release_year: r.releaseDate ? new Date(r.releaseDate).getFullYear() : null,
            thumbnail_url: r.artworkUrl100 ? r.artworkUrl100.replace("100x100bb", "400x400bb") : null,
            api_id: r.trackId ? r.trackId.toString() : null,
            external_url: r.trackViewUrl || null,
            is_local: false
          }))
          .filter(r => r.thumbnail_url)

      } else if (mediaType === "album") {
        const url = `https://itunes.apple.com/search?term=${encodeURIComponent(query)}&media=music&entity=album&limit=5&country=US`
        const response = await fetch(url)
        const data = await response.json()
        return (data.results || []).map(r => ({
          title: r.collectionName,
          artist: r.artistName,
          genre: r.primaryGenreName,
          release_year: r.releaseDate ? new Date(r.releaseDate).getFullYear() : null,
          thumbnail_url: r.artworkUrl100 ? r.artworkUrl100.replace("100x100bb", "500x500bb") : null,
          api_id: r.collectionId ? r.collectionId.toString() : null,
          external_url: r.collectionViewUrl || null,
          is_local: false
        })).filter(r => r.thumbnail_url)

      } else if (mediaType === "tv_show") {
        const url = `https://api.tvmaze.com/search/shows?q=${encodeURIComponent(query)}`
        const response = await fetch(url)
        const data = await response.json()
        return (data || []).slice(0, 5).map(item => {
          const show = item.show
          return {
            title: show.name,
            network: show.network ? show.network.name : (show.webChannel ? show.webChannel.name : null),
            release_year: show.premiered ? new Date(show.premiered).getFullYear() : null,
            thumbnail_url: show.image ? (show.image.original || show.image.medium) : null,
            api_id: show.id ? show.id.toString() : null,
            external_url: show.officialSite || show.url || null,
            is_local: false
          }
        }).filter(r => r.thumbnail_url)

      } else if (mediaType === "comic") {
        const url = `https://openlibrary.org/search.json?q=${encodeURIComponent(query)}&limit=5`
        const response = await fetch(url)
        const data = await response.json()
        return (data.docs || []).map(doc => {
          const author = doc.author_name ? doc.author_name.join(", ") : null
          const releaseYear = doc.first_publish_year || null
          const apiId = doc.key ? doc.key.replace("/works/", "") : null
          const coverUrl = doc.cover_i ? `https://covers.openlibrary.org/b/id/${doc.cover_i}-L.jpg` : null
          return {
            title: doc.title,
            writer: author,
            release_year: releaseYear,
            thumbnail_url: coverUrl,
            api_id: apiId,
            external_url: doc.key ? `https://openlibrary.org${doc.key}` : null,
            is_local: false
          }
        }).filter(r => r.thumbnail_url)

      } else if (mediaType === "video_game") {
        // Handled server-side in MediaController#autocomplete to bypass CORS
        return []
      }
      return []
    } catch (err) {
      console.error(`Error querying web API for ${mediaType}:`, err)
      return []
    }
  }

  selectOption(option) {
    // 1. Update cover art URL and previews
    this.thumbnailUrlTarget.value = option.thumbnail_url
    this.previewImgTarget.src = option.thumbnail_url
    this.previewImgTarget.style.display = "block"
    this.placeholderTarget.style.display = "none"

    // 2. Auto-populate title (only if current input is clean/substantially same)
    if (this.hasTitleInputTarget && (!this.titleInputTarget.value || option.title.toLowerCase().startsWith(this.titleInputTarget.value.toLowerCase().trim()))) {
      this.titleInputTarget.value = option.title
    }

    // 3. Auto-populate targets dynamically
    if (this.hasDirectorTarget) this.directorTarget.value = option.director || ""
    if (this.hasArtistTarget) this.artistTarget.value = option.artist || ""
    if (this.hasWriterTarget) this.writerTarget.value = option.writer || ""
    if (this.hasPublisherTarget) this.publisherTarget.value = option.publisher || ""
    if (this.hasReleaseYearTarget) this.releaseYearTarget.value = option.release_year || ""
    if (this.hasGenreTarget) this.genreTarget.value = option.genre || ""
    if (this.hasNetworkTarget) this.networkTarget.value = option.network || ""
    if (this.hasDeveloperTarget) this.developerTarget.value = option.developer || ""
    if (this.hasPlatformTarget) this.platformTarget.value = option.platform || ""
    if (this.hasSeasonTarget) this.seasonTarget.value = option.season || ""
    if (this.hasEpisodeTarget) this.episodeTarget.value = option.episode || ""
    if (this.hasIssueNumberTarget) this.issueNumberTarget.value = option.issue_number || ""
    if (this.hasApiIdTarget) this.apiIdTarget.value = option.api_id || ""
    if (this.hasExternalUrlTarget) this.externalUrlTarget.value = option.external_url || ""
  }
}
