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
    "season", "episode", "issueNumber"
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

      this.statusTextTarget.textContent = "Select a cover to pre-fill details:"

      allResults.forEach((option, index) => {
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
        else if (mediaType === "wrestling_event") subtitle = option.promotion || ""
        
        const yearInfo = option.release_year ? ` (${option.release_year})` : ""
        const tooltipText = `${option.title}${yearInfo} ${subtitle ? `- ${subtitle}` : ""}`

        imgBtn.innerHTML = `
          <img src="${option.thumbnail_url}" alt="${option.title}">
          <span class="option-badge ${badgeClass}">${badgeText}</span>
          <div class="option-tooltip">${tooltipText}</div>
        `

        imgBtn.addEventListener("click", () => {
          this.optionsGridTarget.querySelectorAll(".thumbnail-option-card").forEach(card => card.classList.remove("selected"))
          imgBtn.classList.add("selected")

          this.selectOption(option)
        })

        this.optionsGridTarget.appendChild(imgBtn)
      })

      // Auto-select first cover if user hasn't selected one
      const firstCard = this.optionsGridTarget.querySelector(".thumbnail-option-card")
      if (firstCard) firstCard.click()

    } catch (err) {
      console.error("Error fetching thumbnails:", err)
      this.statusTextTarget.textContent = "Error loading covers."
    }
  }

  async queryWebAPI(query, mediaType) {
    try {
      if (mediaType === "movie") {
        // Search globally first, filter for feature-movie to bypass iTunes media=movie API limitations
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
          is_local: false
        })).filter(r => r.thumbnail_url)

      } else if (mediaType === "tv_show") {
        // TVmaze API: Completely free, no API key required, highly reliable TV metadata
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
            is_local: false
          }
        }).filter(r => r.thumbnail_url)

      } else if (mediaType === "comic") {
        const url = `https://www.googleapis.com/books/v1/volumes?q=${encodeURIComponent(query)}&maxResults=5`
        const response = await fetch(url)
        const data = await response.json()
        return (data.items || []).map(item => {
          const info = item.volumeInfo
          const imageLinks = info?.imageLinks
          const year = info?.publishedDate ? new Date(info.publishedDate).getFullYear() : null
          return {
            title: info.title,
            writer: info.authors ? info.authors.join(", ") : null,
            publisher: info.publisher,
            release_year: isNaN(year) ? null : year,
            thumbnail_url: imageLinks?.thumbnail || imageLinks?.smallThumbnail,
            is_local: false
          }
        }).filter(r => r.thumbnail_url).map(r => {
          r.thumbnail_url = r.thumbnail_url.replace("http://", "https://")
          return r
        })

      } else if (mediaType === "wrestling_event") {
        const url = `https://itunes.apple.com/search?term=${encodeURIComponent(query)}&limit=15&country=US`
        const response = await fetch(url)
        const data = await response.json()
        return (data.results || [])
          .filter(r => r.kind === "feature-movie" || r.kind === "tv-episode")
          .slice(0, 5)
          .map(r => ({
            title: r.trackName || r.collectionName,
            promotion: r.artistName,
            date: r.releaseDate ? r.releaseDate.split("T")[0] : null,
            thumbnail_url: r.artworkUrl100 ? r.artworkUrl100.replace("100x100bb", "400x400bb") : null,
            is_local: false
          }))
          .filter(r => r.thumbnail_url)
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
    if (this.hasDirectorTarget && option.director) this.directorTarget.value = option.director
    if (this.hasArtistTarget && option.artist) this.artistTarget.value = option.artist
    if (this.hasWriterTarget && option.writer) this.writerTarget.value = option.writer
    if (this.hasPublisherTarget && option.publisher) this.publisherTarget.value = option.publisher
    if (this.hasReleaseYearTarget && option.release_year) this.releaseYearTarget.value = option.release_year
    if (this.hasGenreTarget && option.genre) this.genreTarget.value = option.genre
    if (this.hasNetworkTarget && option.network) this.networkTarget.value = option.network
    if (this.hasVenueTarget && option.venue) this.venueTarget.value = option.venue
    if (this.hasPromotionTarget && option.promotion) this.promotionTarget.value = option.promotion
    if (this.hasDateTarget && option.date) this.dateTarget.value = option.date
    if (this.hasSeasonTarget && option.season) this.seasonTarget.value = option.season
    if (this.hasEpisodeTarget && option.episode) this.episodeTarget.value = option.episode
    if (this.hasIssueNumberTarget && option.issue_number) this.issueNumberTarget.value = option.issue_number
  }
}
