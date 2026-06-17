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
    "season", "episode", "issueNumber", "apiId", "externalUrl", "manualFormSection", "developer", "platform",
    "searchStage", "detailsStage", "backBtn", "modalTitle", "selectedTitleDisplay"
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
      this.showDetailsStage(currentTitle, this.hasReleaseYearTarget ? this.releaseYearTarget.value : null)
    } else {
      this.goToSearch()
    }
    this.element.dataset.connected = "true"
  }

  search() {
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
  }

    showManualForm() {
    const title = this.titleInputTarget.value.trim() || "New Item"
    this.showDetailsStage(title, this.hasReleaseYearTarget ? this.releaseYearTarget.value : null)
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
        video_game: "Log Video Game"
      }
      this.modalTitleTarget.textContent = mediaNames[this.mediaTypeValue] || "Log Media"
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

      // 1. Fetch Local Matches First
      try {
        const localResponse = await fetch(`/media/autocomplete?q=${encodeURIComponent(title)}&type=${mediaType}`)
        if (this.currentQuery !== title) return // Abort if query changed
        if (localResponse.ok) {
          const localData = await localResponse.json()
          allResults = allResults.concat(localData)
        }
      } catch (localErr) {
        console.error("Local autocomplete failed:", localErr)
      }

      // 2. Fetch Web Matches
      if (this.currentQuery !== title) return // Abort if query changed
      let webResults = await this.queryWebAPI(query, mediaType)
      
      if (this.currentQuery !== title) return // Abort if query changed

      // Retry with simplified query if 0 results
      const words = query.split(/\s+/)
      if (webResults.length === 0 && words.length > 3) {
        const simplifiedQuery = words.slice(0, 3).join(" ")
        webResults = await this.queryWebAPI(simplifiedQuery, mediaType)
        if (this.currentQuery !== title) return
      }
      if (webResults.length === 0 && words.length > 2) {
        const simplifiedQuery2 = words.slice(0, 2).join(" ")
        webResults = await this.queryWebAPI(simplifiedQuery2, mediaType)
        if (this.currentQuery !== title) return
      }

      allResults = allResults.concat(webResults)

      if (this.currentQuery !== title) return // Abort if query changed

      // 3. Render Combined Options
      if (allResults.length === 0) {
        this.statusTextTarget.textContent = "No covers found. Standard category icon will be used."
        return
      }

      this.statusTextTarget.textContent = "Select a result below:"

      allResults.forEach((option) => {
        const imgBtn = document.createElement("div")
        imgBtn.className = "thumbnail-option-card"
        
        const badgeClass = option.is_local ? "local" : "web"
        const badgeText = option.is_local ? "Local" : "Web"
        
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
        `

        imgBtn.addEventListener("click", (e) => {
          this.optionsGridTarget.querySelectorAll(".thumbnail-option-card").forEach(card => card.classList.remove("selected"))
          imgBtn.classList.add("selected")

          // User clicked explicitly, so populate all text fields and transition to details view!
          this.selectOption(option, true)
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
      console.error("Error fetching thumbnails:", err)
      this.statusTextTarget.textContent = "Error loading covers."
    }
  }

  // ── Helper: Query Wikipedia using OpenSearch + REST Summary API (Robust & Multi-Format) ──
  async queryWikipedia(query, mediaType) {
    try {
      let searchQuery = query
      if (mediaType === "movie") searchQuery += " film"
      else if (mediaType === "tv_show") searchQuery += " TV series"
      else if (mediaType === "comic") searchQuery += " comic book"
      else if (mediaType === "video_game") searchQuery += " video game"
      else if (mediaType === "album") searchQuery += " album"

      const searchUrl = `https://en.wikipedia.org/w/api.php?action=query&list=search&srsearch=${encodeURIComponent(searchQuery)}&format=json&origin=*`
      const res = await fetch(searchUrl)
      if (!res.ok) return null
      const data = await res.json()
      const searchResults = data.query?.search || []
      if (searchResults.length === 0) return null

      const results = []
      // Query summaries for the top 3 Wikipedia pages
      for (const item of searchResults.slice(0, 3)) {
        const pageTitle = item.title
        const summaryUrl = `https://en.wikipedia.org/api/rest_v1/page/summary/${encodeURIComponent(pageTitle.replace(/ /g, "_"))}`
        try {
          const sumRes = await fetch(summaryUrl)
          if (sumRes.ok) {
            const sumData = await sumRes.json()
            if (sumData.originalimage && sumData.originalimage.source) {
              let releaseYear = null
              const desc = sumData.description || ""
              const yearMatch = desc.match(/\b(19\d\d|20\d\d)\b/)
              if (yearMatch) {
                releaseYear = parseInt(yearMatch[1], 10)
              }
              const cleanTitle = sumData.title ? sumData.title.replace(/\s*\(film\)$/i, "").replace(/\s*\(TV series\)$/i, "").replace(/\s*\(video game\)$/i, "").replace(/\s*\(album\)$/i, "") : pageTitle
              results.push({
                title: cleanTitle,
                thumbnail_url: sumData.originalimage.source,
                external_url: sumData.content_urls?.desktop?.page || null,
                release_year: releaseYear,
                is_local: false
              })
            }
          }
        } catch (sumErr) {
          console.error("Wikipedia summary fetch failed for:", pageTitle, sumErr)
        }
      }
      return results.length > 0 ? results : null
    } catch (e) {
      console.error("Wikipedia search failed:", e)
      return null
    }
  }

  deduplicateResults(results) {
    const seen = new Map()
    for (const item of results) {
      const key = (item.title || "").toLowerCase().trim()
      if (!key) continue
      const existing = seen.get(key)
      if (!existing) {
        seen.set(key, item)
      } else if (!existing.thumbnail_url && item.thumbnail_url) {
        seen.set(key, item)
      }
    }
    return Array.from(seen.values())
  }

  async queryWebAPI(query, mediaType) {
    try {
      if (mediaType === "movie") {
        let results = []
        // Wikipedia search first (excellent free source for movie cover art & summaries, bypasses iTunes issues)
        try {
          const wikiResults = await this.queryWikipedia(query, "movie")
          if (wikiResults) results = results.concat(wikiResults)
        } catch (e) {
          console.error("Wikipedia movie search failed:", e)
        }

        // iTunes Movie Search secondary
        try {
          const url = `https://itunes.apple.com/search?term=${encodeURIComponent(query)}&entity=movie&limit=5&country=US`
          const response = await fetch(url)
          if (response.ok) {
            const data = await response.json()
            const itunesResults = (data.results || []).map(r => ({
              title: r.trackName,
              director: r.artistName,
              release_year: r.releaseDate ? new Date(r.releaseDate).getFullYear() : null,
              thumbnail_url: r.artworkUrl100 ? r.artworkUrl100.replace("100x100bb", "400x400bb") : null,
              api_id: r.trackId ? r.trackId.toString() : null,
              external_url: r.trackViewUrl || null,
              is_local: false
            })).filter(r => r.thumbnail_url)
            results = results.concat(itunesResults)
          }
        } catch (e) {
          console.error("iTunes movie search failed:", e)
        }

        return this.deduplicateResults(results)

      } else if (mediaType === "album") {
        let results = []
        try {
          const url = `https://itunes.apple.com/search?term=${encodeURIComponent(query)}&media=music&entity=album&limit=5&country=US`
          const response = await fetch(url)
          if (response.ok) {
            const data = await response.json()
            results = (data.results || []).map(r => ({
              title: r.collectionName,
              artist: r.artistName,
              genre: r.primaryGenreName,
              release_year: r.releaseDate ? new Date(r.releaseDate).getFullYear() : null,
              thumbnail_url: r.artworkUrl100 ? r.artworkUrl100.replace("100x100bb", "500x500bb") : null,
              api_id: r.collectionId ? r.collectionId.toString() : null,
              external_url: r.collectionViewUrl || null,
              is_local: false
            })).filter(r => r.thumbnail_url)
          }
        } catch (e) {
          console.error("iTunes search failed:", e)
        }

        // Wikipedia fallback for albums
        if (results.length < 3) {
          try {
            const wikiResults = await this.queryWikipedia(query, "album")
            if (wikiResults) results = results.concat(wikiResults)
          } catch (e) {
            console.error("Wikipedia album fallback failed:", e)
          }
        }

        return this.deduplicateResults(results)

      } else if (mediaType === "tv_show") {
        let results = []
        try {
          const url = `https://api.tvmaze.com/search/shows?q=${encodeURIComponent(query)}`
          const response = await fetch(url)
          if (response.ok) {
            const data = await response.json()
            results = (data || []).slice(0, 5).map(item => {
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
          }
        } catch (e) {
          console.error("TVmaze search failed:", e)
        }

        // Wikipedia fallback for TV shows
        if (results.length < 3) {
          try {
            const wikiResults = await this.queryWikipedia(query, "tv_show")
            if (wikiResults) results = results.concat(wikiResults)
          } catch (e) {
            console.error("Wikipedia TV fallback failed:", e)
          }
        }

        return this.deduplicateResults(results)

      } else if (mediaType === "comic") {
        let results = []
        // Wikipedia search first (highly accurate for comic box covers and summaries)
        try {
          const wikiResults = await this.queryWikipedia(query, "comic")
          if (wikiResults) results = results.concat(wikiResults)
        } catch (e) {
          console.error("Wikipedia comic search failed:", e)
        }

        // Google Books (secondary)
        try {
          const gbUrl = `https://www.googleapis.com/books/v1/volumes?q=${encodeURIComponent(query + " comic")}&maxResults=5&printType=books`
          const gbResponse = await fetch(gbUrl)
          if (gbResponse.ok) {
            const gbData = await gbResponse.json()
            const gbResults = (gbData.items || []).map(item => {
              const info = item.volumeInfo || {}
              const rawThumb = info.imageLinks?.thumbnail || null
              const thumbnail = rawThumb ? rawThumb.replace("http:", "https:").replace("zoom=1", "zoom=2") : null
              return {
                title: info.title,
                writer: info.authors?.join(", ") || null,
                publisher: info.publisher || null,
                release_year: info.publishedDate ? new Date(info.publishedDate).getFullYear() : null,
                thumbnail_url: thumbnail,
                api_id: item.id,
                external_url: info.infoLink || null,
                is_local: false
              }
            }).filter(r => r.thumbnail_url)
            results = results.concat(gbResults)
          }
        } catch (gbErr) {
          console.error("Google Books search failed:", gbErr)
        }

        // Open Library (tertiary)
        try {
          const url = `https://openlibrary.org/search.json?q=${encodeURIComponent(query)}&limit=3`
          const response = await fetch(url)
          if (response.ok) {
            const data = await response.json()
            const olResults = (data.docs || []).map(doc => {
              const author = doc.author_name ? doc.author_name.join(", ") : null
              const releaseYear = doc.first_publish_year || null
              const apiId = doc.key ? doc.key.replace("/works/", "") : null
              const coverUrl = doc.cover_i ? `https://covers.openlibrary.org/b/id/${doc.cover_i}-L.jpg` : null
              return {
                title: doc.title,
                writer: author,
                publisher: doc.publisher ? doc.publisher.join(", ") : null,
                release_year: releaseYear,
                thumbnail_url: coverUrl,
                api_id: apiId,
                external_url: doc.key ? `https://openlibrary.org${doc.key}` : null,
                is_local: false
              }
            }).filter(r => r.thumbnail_url)
            results = results.concat(olResults)
          }
        } catch (e) {
          console.error("Open Library search failed:", e)
        }

        return this.deduplicateResults(results)

      } else if (mediaType === "video_game") {
        // Video games search is handled server-side to resolve Steam API and Wikipedia queries
        return []
      }
      return []
    } catch (err) {
      console.error(`Error querying web API for ${mediaType}:`, err)
      return []
    }
  }

  selectOption(option, isManualClick = false) {
    // 1. Update cover art URL and previews
    this.thumbnailUrlTarget.value = option.thumbnail_url
    this.previewImgTarget.src = option.thumbnail_url
    this.previewImgTarget.style.display = "block"
    this.placeholderTarget.style.display = "none"

    if (isManualClick) {
      // 2. Auto-populate text fields only on direct selection
      if (this.hasTitleInputTarget) {
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

      // 4. Transition to details view!
      this.showDetailsStage(option.title, option.release_year)
    }
  }
}
